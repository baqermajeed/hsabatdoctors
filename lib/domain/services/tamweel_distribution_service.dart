/// توزيع أجور التمويل:
/// 75% للطبيب المالك + 25% لباقي الأطباء المختارين
/// بنسبة صافي كل طبيب (المبلغ بعد النسبة).
class TamweelDistributionService {
  const TamweelDistributionService();

  static const double ownerRatio = 0.75;
  static const double othersRatio = 0.25;

  Map<String, double> distribute({
    required double totalTamweel,
    required Iterable<String> selectedDoctors,
    required String? ownerDoctor,
    required Map<String, double> doctorNetAmounts,
  }) {
    final safeTotal = totalTamweel < 0 ? 0.0 : totalTamweel;
    final selected = selectedDoctors
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    if (selected.isEmpty || safeTotal == 0) {
      return {for (final doctor in selected) doctor: 0.0};
    }

    final owner = ownerDoctor?.trim();
    final hasOwner = owner != null && owner.isNotEmpty && selected.contains(owner);
    final others = hasOwner
        ? selected.where((name) => name != owner).toList()
        : List<String>.from(selected);

    if (!hasOwner) {
      return _splitByNet(doctors: selected, pool: safeTotal, nets: doctorNetAmounts);
    }

    if (others.isEmpty) {
      return {owner!: safeTotal};
    }

    final othersNetsSum = others.fold<double>(
      0,
      (sum, name) => sum + _netOf(name, doctorNetAmounts),
    );

    if (othersNetsSum <= 0) {
      return {
        owner!: safeTotal,
        for (final doctor in others) doctor: 0.0,
      };
    }

    final ownerShare = safeTotal * ownerRatio;
    final othersPool = safeTotal * othersRatio;
    final result = <String, double>{owner!: ownerShare};

    for (final doctor in others) {
      final net = _netOf(doctor, doctorNetAmounts);
      result[doctor] = othersPool * (net / othersNetsSum);
    }
    return result;
  }

  Map<String, double> _splitByNet({
    required List<String> doctors,
    required double pool,
    required Map<String, double> nets,
  }) {
    final sum = doctors.fold<double>(0, (acc, name) => acc + _netOf(name, nets));
    if (sum <= 0) {
      final equal = pool / doctors.length;
      return {for (final doctor in doctors) doctor: equal};
    }
    return {
      for (final doctor in doctors) doctor: pool * (_netOf(doctor, nets) / sum),
    };
  }

  double _netOf(String doctor, Map<String, double> nets) {
    final value = nets[doctor] ?? 0;
    return value < 0 ? 0 : value;
  }
}
