class EmergencyContact {
  const EmergencyContact({required this.name, required this.phoneNumber});

  static const empty = EmergencyContact(name: '', phoneNumber: '');

  final String name;
  final String phoneNumber;

  bool get isComplete =>
      name.trim().isNotEmpty && phoneNumber.trim().isNotEmpty;

  EmergencyContact copyWith({String? name, String? phoneNumber}) {
    return EmergencyContact(
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
    );
  }
}
