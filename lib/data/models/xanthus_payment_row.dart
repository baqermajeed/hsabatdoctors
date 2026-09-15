class XanthusPaymentRow {
  const XanthusPaymentRow({
    required this.paymentId,
    required this.invoiceId,
    required this.patientName,
    required this.phoneNumber,
    required this.amount,
    required this.type,
    required this.bankName,
    required this.paymentDate,
    required this.treatmentDoctor,
  });

  final String paymentId;
  final String invoiceId;
  final String patientName;
  final String phoneNumber;
  final double amount;
  final String type;
  final String bankName;
  final DateTime paymentDate;
  final String treatmentDoctor;

  bool get isRafidainInstallment =>
      type.trim().toLowerCase() == 'credit card' &&
      bankName.trim() == 'كي كار اقساط الرافدين';

  String get paymentMethodLabel {
    if (isRafidainInstallment) {
      return 'رافدين - أقساط';
    }
    final normalizedType = type.trim().toLowerCase();
    if (normalizedType.isEmpty) {
      return 'غير محدد';
    }
    if (normalizedType == 'cash') {
      return 'نقدي';
    }
    if (normalizedType == 'credit card' && bankName.trim().isNotEmpty) {
      return 'بطاقة - ${bankName.trim()}';
    }
    if (bankName.trim().isEmpty) {
      return type.trim();
    }
    return '${type.trim()} - ${bankName.trim()}';
  }

  factory XanthusPaymentRow.fromMap(Map<String, dynamic> map) {
    return XanthusPaymentRow(
      paymentId: _readAsString(map, 'ID'),
      invoiceId: _readAsString(map, 'nom'),
      patientName: _readAsString(map, 'paname'),
      phoneNumber: _readAsString(map, 'phone'),
      amount: _readAsDouble(map, 'monyyy'),
      type: _readAsString(map, 'typ'),
      bankName: _readAsString(map, 'banknom'),
      paymentDate:
          _readAsDate(map, 'date1') ?? DateTime.fromMillisecondsSinceEpoch(0),
      treatmentDoctor: _readAsString(map, 'treatmentDoctor'),
    );
  }

  static String _readAsString(Map<String, dynamic> map, String key) {
    final value = map.entries
        .firstWhere(
          (entry) => entry.key.toLowerCase() == key.toLowerCase(),
          orElse: () => MapEntry(key, null),
        )
        .value;
    return value?.toString().trim() ?? '';
  }

  static double _readAsDouble(Map<String, dynamic> map, String key) {
    final value = map.entries
        .firstWhere(
          (entry) => entry.key.toLowerCase() == key.toLowerCase(),
          orElse: () => MapEntry(key, null),
        )
        .value;
    if (value == null) {
      return 0;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value.toString()) ?? 0;
  }

  static DateTime? _readAsDate(Map<String, dynamic> map, String key) {
    final value = map.entries
        .firstWhere(
          (entry) => entry.key.toLowerCase() == key.toLowerCase(),
          orElse: () => MapEntry(key, null),
        )
        .value;
    if (value is DateTime) {
      return value;
    }
    if (value == null) {
      return null;
    }
    return DateTime.tryParse(value.toString());
  }
}
