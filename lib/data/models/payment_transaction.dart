class PaymentTransaction {
  const PaymentTransaction({
    required this.id,
    required this.nom,
    required this.patientName,
    required this.amount,
    required this.type,
    required this.bankName,
    required this.paymentDate,
  });

  final String id;
  final String nom;
  final String patientName;
  final double amount;
  final String type;
  final String bankName;
  final DateTime? paymentDate;

  factory PaymentTransaction.fromMap(Map<String, dynamic> map) {
    return PaymentTransaction(
      id: _readAsString(map, 'ID'),
      nom: _readAsString(map, 'nom'),
      patientName: _readAsString(map, 'paname'),
      amount: _readAsDouble(map, 'monyyy'),
      type: _readAsString(map, 'typ'),
      bankName: _readAsString(map, 'banknom'),
      paymentDate: _readAsDate(map, 'date1'),
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
    if (value == null) {
      return null;
    }
    if (value is DateTime) {
      return value;
    }
    return DateTime.tryParse(value.toString());
  }
}
