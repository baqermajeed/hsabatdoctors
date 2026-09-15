import 'dart:convert';

class RafidainInstallmentPlan {
  /// نسبة منصة مصرف الرافدين تُقتطع قبل توزيع المبلغ على الأقساط.
  static const double platformFeeRate = 0.10;

  static double platformFeeFrom(double grossAmount) =>
      grossAmount * platformFeeRate;

  static double netAfterPlatformFee(double grossAmount) =>
      grossAmount * (1 - platformFeeRate);

  const RafidainInstallmentPlan({
    required this.paymentId,
    required this.invoiceId,
    required this.patientName,
    required this.phoneNumber,
    required this.treatmentDoctor,
    required this.originalAmount,
    required this.sourcePaymentDate,
    required this.months,
    required this.startDate,
    required this.monthlyAmount,
    this.localOnly = false,
  });

  final String paymentId;
  final String invoiceId;
  final String patientName;
  final String phoneNumber;
  final String treatmentDoctor;
  final double originalAmount;
  final DateTime sourcePaymentDate;
  final int months;
  final DateTime startDate;
  final double monthlyAmount;
  final bool localOnly;

  bool appliesToMonth({required int year, required int month}) {
    final firstMonthIndex = startDate.year * 12 + startDate.month;
    final targetMonthIndex = year * 12 + month;
    final diff = targetMonthIndex - firstMonthIndex;
    return diff >= 0 && diff < months;
  }

  DateTime installmentDateForMonth({required int year, required int month}) {
    return DateTime(year, month, 1);
  }

  Map<String, dynamic> toMap() {
    return {
      'paymentId': paymentId,
      'invoiceId': invoiceId,
      'patientName': patientName,
      'phoneNumber': phoneNumber,
      'treatmentDoctor': treatmentDoctor,
      'originalAmount': originalAmount,
      'sourcePaymentDate': sourcePaymentDate.toIso8601String(),
      'months': months,
      'startDate': startDate.toIso8601String(),
      'monthlyAmount': monthlyAmount,
      'localOnly': localOnly,
    };
  }

  factory RafidainInstallmentPlan.fromMap(Map<String, dynamic> map) {
    return RafidainInstallmentPlan(
      paymentId: map['paymentId']?.toString() ?? '',
      invoiceId: map['invoiceId']?.toString() ?? '',
      patientName: map['patientName']?.toString() ?? '',
      phoneNumber: map['phoneNumber']?.toString() ?? '',
      treatmentDoctor: map['treatmentDoctor']?.toString() ?? '',
      originalAmount: _toDouble(map['originalAmount']),
      sourcePaymentDate:
          DateTime.tryParse(map['sourcePaymentDate']?.toString() ?? '') ??
          DateTime.now(),
      months: _toInt(map['months'], fallback: 1),
      startDate:
          DateTime.tryParse(map['startDate']?.toString() ?? '') ?? DateTime.now(),
      monthlyAmount: _toDouble(map['monthlyAmount']),
      localOnly: _toBool(map['localOnly']),
    );
  }

  static String encodeList(List<RafidainInstallmentPlan> plans) {
    return jsonEncode(plans.map((plan) => plan.toMap()).toList());
  }

  static List<RafidainInstallmentPlan> decodeList(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const [];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return const [];
    }
    return decoded
        .whereType<Map>()
        .map((item) => item.map((k, v) => MapEntry(k.toString(), v)))
        .map(RafidainInstallmentPlan.fromMap)
        .toList();
  }

  static double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int _toInt(dynamic value, {required int fallback}) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static bool _toBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    final raw = value?.toString().trim().toLowerCase() ?? '';
    return raw == '1' || raw == 'true' || raw == 'yes';
  }
}
