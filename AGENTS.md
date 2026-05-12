# Project Agent Guide

## Project Shape

- This is a Flutter application.
- Use Clean Architecture and MVVM as the default implementation style.
- Keep dependencies flowing inward: `presentation -> domain -> data -> platform`.
- Views render UI only. ViewModels own UI state and user actions. Use cases own business decisions. Repositories own data access. Platform adapters own OS permissions, sensors, notifications, and SMS delivery.

## Activity Monitoring Rules

- The activity window is local device time, weekdays only, from 11:00 to 13:00.
- The 13:00 evaluation checks whether the user is at or below the configured thresholds.
- Default thresholds are 2000 steps and 1.0 km until product requirements replace them.
- Distance is calculated from GPS samples by accumulating reliable point-to-point distance.
- Emergency contacts are entered inside the app and do not require address book access.

## Platform Rules

- Android may send SMS directly after the user grants permission.
- Android background monitoring uses exact alarms to start and evaluate a short-lived foreground service for the weekday 11:00-13:00 window.
- iOS must not attempt silent/direct SMS sending. Use strong local notification plus a user-visible SMS compose/deep-link fallback.
- iOS background monitoring is best-effort: use Always Location/CoreMotion where allowed, but never promise exact 13:00 execution after force quit or OS suspension.
- Keep Android and iOS permission differences explicit in code and documentation.
- Strong alerts should use the maximum local notification behavior available without private APIs. iOS Critical Alerts are out of scope unless the entitlement is approved later.

## Verification

- The local shell may not expose `flutter` until the profile is loaded.
- Run analysis with:

```sh
source $HOME/.zprofile >/dev/null 2>&1; flutter analyze
```

- Run tests with:

```sh
source $HOME/.zprofile >/dev/null 2>&1; flutter test
```
