class SmsDeliverySnapshot {
  const SmsDeliverySnapshot({
    this.status,
    this.error,
    this.attemptedAt,
    this.sentAt,
    this.phoneNumber,
    this.dateKey,
  });

  const SmsDeliverySnapshot.empty()
    : status = null,
      error = null,
      attemptedAt = null,
      sentAt = null,
      phoneNumber = null,
      dateKey = null;

  final String? status;
  final String? error;
  final DateTime? attemptedAt;
  final DateTime? sentAt;
  final String? phoneNumber;
  final String? dateKey;

  bool get hasAttempt => attemptedAt != null || status != null;

  bool get sent => status == 'sent' || sentAt != null;

  String get label {
    return switch (status) {
      'sent' => '발송 완료',
      'requested' => '전송 요청됨',
      'attempted' => '발송 시도',
      'failed' => '발송 실패',
      'no_permission' => '권한 필요',
      'no_contact' => '보호자 없음',
      _ => hasAttempt ? '확인 필요' : '기록 없음',
    };
  }
}
