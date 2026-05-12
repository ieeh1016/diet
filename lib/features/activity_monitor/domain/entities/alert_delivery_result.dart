class AlertDeliveryResult {
  const AlertDeliveryResult({
    required this.notificationShown,
    required this.smsAttempted,
    required this.smsSent,
    required this.smsFallbackOpened,
    this.errorMessage,
  });

  const AlertDeliveryResult.none()
    : notificationShown = false,
      smsAttempted = false,
      smsSent = false,
      smsFallbackOpened = false,
      errorMessage = null;

  final bool notificationShown;
  final bool smsAttempted;
  final bool smsSent;
  final bool smsFallbackOpened;
  final String? errorMessage;
}
