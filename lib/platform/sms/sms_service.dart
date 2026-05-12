import 'dart:io';

import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class SmsSendResult {
  const SmsSendResult({required this.sent, required this.fallbackOpened});

  final bool sent;
  final bool fallbackOpened;
}

class SmsService {
  static const _channel = MethodChannel('diet/sms');

  Future<SmsSendResult> sendEmergencySms({
    required String phoneNumber,
    required String message,
  }) async {
    if (Platform.isAndroid) {
      final sent = await _channel.invokeMethod<bool>(
        'sendSms',
        <String, String>{'phoneNumber': phoneNumber, 'message': message},
      );
      return SmsSendResult(sent: sent ?? false, fallbackOpened: false);
    }

    final uri = Uri(
      scheme: 'sms',
      path: phoneNumber,
      queryParameters: <String, String>{'body': message},
    );
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    return SmsSendResult(sent: false, fallbackOpened: opened);
  }
}
