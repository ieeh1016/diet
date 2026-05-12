import Flutter
import CoreLocation
import CoreMotion
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      BackgroundMonitoringBridge.shared.configure(messenger: controller.binaryMessenger)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func applicationDidEnterBackground(_ application: UIApplication) {
    BackgroundMonitoringBridge.shared.startIfWithinWindow()
    super.applicationDidEnterBackground(application)
  }
}

final class BackgroundMonitoringBridge: NSObject, CLLocationManagerDelegate {
  static let shared = BackgroundMonitoringBridge()

  private let channelName = "diet/background_monitoring"
  private let locationManager = CLLocationManager()
  private let pedometer = CMPedometer()
  private var channel: FlutterMethodChannel?

  private override init() {
    super.init()
    locationManager.delegate = self
    locationManager.pausesLocationUpdatesAutomatically = true
    locationManager.distanceFilter = 25
    locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
  }

  func configure(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    channel?.setMethodCallHandler { [weak self] call, result in
      self?.handle(call: call, result: result)
    }
  }

  func startIfWithinWindow() {
    let now = Date()
    if isWeekday(now), now >= windowStart(for: now), now < windowEnd(for: now) {
      startWindow()
    }
  }

  private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "currentStatus":
      result(statusMap())
    case "scheduleWeekdayMonitoring":
      UserDefaults.standard.set(true, forKey: key("background.is_scheduled"))
      result(statusMap(degradedReason: bestEffortReasonIfNeeded()))
    case "startWindow":
      startWindow()
      result(statusMap())
    case "stopAndEvaluate":
      stopAndEvaluate(result: result)
    case "openExactAlarmSettings":
      result(false)
    case "cancelSchedule":
      UserDefaults.standard.set(false, forKey: key("background.is_scheduled"))
      stopLocation()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func startWindow() {
    let now = Date()
    let defaults = UserDefaults.standard
    defaults.set("active", forKey: key("background.session.status"))
    defaults.set(iso(now), forKey: key("background.session.started_at"))
    defaults.set(0, forKey: key("background.session.steps"))
    defaults.set(0.0, forKey: key("background.session.distance_meters"))

    if CLLocationManager.authorizationStatus() == .authorizedAlways {
      locationManager.allowsBackgroundLocationUpdates = true
      locationManager.startUpdatingLocation()
    } else {
      defaults.set(
        "상시 위치 권한이 없어 iOS 백그라운드 GPS 이동거리 기록이 제한돼요.",
        forKey: key("background.degraded_reason")
      )
      if CLLocationManager.authorizationStatus() == .notDetermined {
        locationManager.requestAlwaysAuthorization()
      }
      locationManager.startUpdatingLocation()
    }
  }

  private func stopAndEvaluate(result: @escaping FlutterResult) {
    stopLocation()
    let now = Date()
    let start = readDate("background.session.started_at") ?? windowStart(for: now)
    let end = windowEnd(for: start)

    let finish: (Int) -> Void = { [weak self] steps in
      guard let self else { return }
      let defaults = UserDefaults.standard
      defaults.set("evaluated", forKey: self.key("background.session.status"))
      defaults.set(self.iso(Date()), forKey: self.key("background.session.ended_at"))
      defaults.set(steps, forKey: self.key("background.session.steps"))
      defaults.set(self.dateKey(Date()), forKey: self.key("background.session.evaluated_date_key"))
      result(self.statusMap())
    }

    guard CMPedometer.isStepCountingAvailable() else {
      finish(UserDefaults.standard.integer(forKey: key("background.session.steps")))
      return
    }

    pedometer.queryPedometerData(from: start, to: min(Date(), end)) { data, _ in
      DispatchQueue.main.async {
        let steps = data?.numberOfSteps.intValue ??
          UserDefaults.standard.integer(forKey: self.key("background.session.steps"))
        finish(steps)
      }
    }
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let location = locations.last, location.horizontalAccuracy > 0, location.horizontalAccuracy <= 65 else {
      return
    }

    let defaults = UserDefaults.standard
    if let lastLatitude = defaults.object(forKey: key("background.session.last_latitude")) as? Double,
       let lastLongitude = defaults.object(forKey: key("background.session.last_longitude")) as? Double {
      let last = CLLocation(latitude: lastLatitude, longitude: lastLongitude)
      let addedMeters = location.distance(from: last)
      if addedMeters >= 5 {
        let current = defaults.double(forKey: key("background.session.distance_meters"))
        defaults.set(current + addedMeters, forKey: key("background.session.distance_meters"))
      }
    }

    defaults.set(location.coordinate.latitude, forKey: key("background.session.last_latitude"))
    defaults.set(location.coordinate.longitude, forKey: key("background.session.last_longitude"))
    defaults.set(location.horizontalAccuracy, forKey: key("background.session.last_accuracy"))
    defaults.set(iso(location.timestamp), forKey: key("background.session.last_timestamp"))
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    UserDefaults.standard.set(
      "iOS 백그라운드 위치 기록에 실패했어요: \(error.localizedDescription)",
      forKey: key("background.degraded_reason")
    )
  }

  private func stopLocation() {
    locationManager.stopUpdatingLocation()
    locationManager.allowsBackgroundLocationUpdates = false
  }

  private func statusMap(degradedReason explicitReason: String? = nil) -> [String: Any?] {
    let defaults = UserDefaults.standard
    let auth = CLLocationManager.authorizationStatus()
    let status = defaults.string(forKey: key("background.session.status")) ?? "idle"
    let degradedReason = explicitReason ?? defaults.string(forKey: key("background.degraded_reason"))

    return [
      "nativeAvailable": true,
      "isScheduled": defaults.bool(forKey: key("background.is_scheduled")),
      "isRunning": status == "active",
      "exactAlarmAvailable": false,
      "locationAlwaysGranted": auth == .authorizedAlways,
      "degradedReason": degradedReason,
      "sessionStatus": status,
      "startedAtMillis": readDate("background.session.started_at")?.timeIntervalSince1970Millis,
      "endedAtMillis": readDate("background.session.ended_at")?.timeIntervalSince1970Millis,
      "steps": defaults.integer(forKey: key("background.session.steps")),
      "distanceMeters": defaults.double(forKey: key("background.session.distance_meters"))
    ]
  }

  private func bestEffortReasonIfNeeded() -> String? {
    CLLocationManager.authorizationStatus() == .authorizedAlways
      ? "iOS 정책상 13:00 정시 실행을 보장할 수 없어 가능한 범위에서 평가해요."
      : "상시 위치 권한이 없어 iOS 백그라운드 GPS 이동거리 기록이 제한돼요."
  }

  private func key(_ value: String) -> String {
    "flutter.\(value)"
  }

  private func readDate(_ key: String) -> Date? {
    guard let value = UserDefaults.standard.string(forKey: self.key(key)) else {
      return nil
    }
    return ISO8601DateFormatter().date(from: value)
  }

  private func iso(_ date: Date) -> String {
    ISO8601DateFormatter().string(from: date)
  }

  private func isWeekday(_ date: Date) -> Bool {
    let weekday = Calendar.current.component(.weekday, from: date)
    return weekday != 1 && weekday != 7
  }

  private func windowStart(for date: Date) -> Date {
    Calendar.current.date(bySettingHour: 11, minute: 0, second: 0, of: date) ?? date
  }

  private func windowEnd(for date: Date) -> Date {
    Calendar.current.date(bySettingHour: 13, minute: 0, second: 0, of: date) ?? date
  }

  private func dateKey(_ date: Date) -> String {
    let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
    return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
  }
}

private extension Date {
  var timeIntervalSince1970Millis: Int64 {
    Int64((timeIntervalSince1970 * 1000.0).rounded())
  }
}
