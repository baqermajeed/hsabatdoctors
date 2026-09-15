import '../../data/models/xanthus_payment_row.dart';
import '../../data/repositories/installment_plan_repository.dart';
import '../../data/repositories/monthly_report_repository.dart';
import '../entities/doctor_monthly_payment_row.dart';
import '../entities/rafidain_installment_plan.dart';

class MonthlyReportResult {
  const MonthlyReportResult({
    required this.rows,
    required this.pendingRafidainPayments,
    required this.totalAmount,
  });

  final List<DoctorMonthlyPaymentRow> rows;
  final List<XanthusPaymentRow> pendingRafidainPayments;
  final double totalAmount;
}

class MonthlyReportService {
  MonthlyReportService({
    required MonthlyReportRepository reportRepository,
    required InstallmentPlanRepository installmentPlanRepository,
  }) : _reportRepository = reportRepository,
       _installmentPlanRepository = installmentPlanRepository;

  final MonthlyReportRepository _reportRepository;
  final InstallmentPlanRepository _installmentPlanRepository;

  Future<List<String>> loadDoctorsFromDatabase() async {
    return _reportRepository.fetchDistinctTreatmentDoctors();
  }

  Future<void> saveInstallmentPlan({
    required XanthusPaymentRow sourcePayment,
    required int months,
  }) async {
    final safeMonths = months < 1 ? 1 : months;
    final startDate = DateTime(
      sourcePayment.paymentDate.year,
      sourcePayment.paymentDate.month + 1,
      1,
    );
    final netAmount =
        RafidainInstallmentPlan.netAfterPlatformFee(sourcePayment.amount);
    final monthlyAmount = netAmount / safeMonths;

    final plan = RafidainInstallmentPlan(
      paymentId: sourcePayment.paymentId,
      invoiceId: sourcePayment.invoiceId,
      patientName: sourcePayment.patientName,
      phoneNumber: sourcePayment.phoneNumber,
      treatmentDoctor: sourcePayment.treatmentDoctor,
      originalAmount: sourcePayment.amount,
      sourcePaymentDate: sourcePayment.paymentDate,
      months: safeMonths,
      startDate: startDate,
      monthlyAmount: monthlyAmount,
    );

    await _installmentPlanRepository.savePlan(plan);
  }

  Future<void> saveLocalOnlyInstallmentPlan({
    required String patientName,
    required String phoneNumber,
    required String treatmentDoctor,
    required double originalAmount,
    required int months,
    required DateTime firstInstallmentDate,
    String? invoiceId,
  }) async {
    final safeMonths = months < 1 ? 1 : months;
    final safeOriginalAmount = originalAmount < 0 ? 0.0 : originalAmount;
    final startDate = DateTime(
      firstInstallmentDate.year,
      firstInstallmentDate.month,
      1,
    );
    final netAmount =
        RafidainInstallmentPlan.netAfterPlatformFee(safeOriginalAmount);
    final monthlyAmount = netAmount / safeMonths;
    final now = DateTime.now();
    final plan = RafidainInstallmentPlan(
      paymentId: 'local_${now.microsecondsSinceEpoch}',
      invoiceId: (invoiceId ?? '').trim().isEmpty
          ? 'LOCAL-${now.millisecondsSinceEpoch}'
          : invoiceId!.trim(),
      patientName: patientName.trim(),
      phoneNumber: phoneNumber.trim(),
      treatmentDoctor: treatmentDoctor.trim(),
      originalAmount: safeOriginalAmount,
      sourcePaymentDate: now,
      months: safeMonths,
      startDate: startDate,
      monthlyAmount: monthlyAmount,
      localOnly: true,
    );
    await _installmentPlanRepository.savePlan(plan);
  }

  Future<MonthlyReportResult> buildMonthlyReport({
    required int year,
    required int month,
    required String doctorName,
  }) async {
    final allPayments = await _reportRepository.fetchPaymentsInMonth(
      year: year,
      month: month,
      doctorName: doctorName,
    );
    return _buildFromPayments(
      allPayments: allPayments,
      doctorName: doctorName,
      isInstallmentInScope: (plan) => plan.appliesToMonth(year: year, month: month),
      installmentDateProvider: (plan) =>
          plan.installmentDateForMonth(year: year, month: month),
    );
  }

  Future<MonthlyReportResult> buildRangeReport({
    required DateTime from,
    required DateTime toInclusive,
    required String doctorName,
  }) async {
    final fromDate = DateTime(from.year, from.month, from.day);
    final toExclusive = DateTime(
      toInclusive.year,
      toInclusive.month,
      toInclusive.day + 1,
    );

    final allPayments = await _reportRepository.fetchPaymentsInRange(
      from: fromDate,
      toExclusive: toExclusive,
      doctorName: doctorName,
    );

    final plans = await _installmentPlanRepository.loadPlans();
    final installmentDatesByPaymentId = <String, DateTime>{};
    for (final plan in plans) {
      final firstMonthIndex = plan.startDate.year * 12 + plan.startDate.month;
      final fromMonthIndex = fromDate.year * 12 + fromDate.month;
      final toMonthIndex = toInclusive.year * 12 + toInclusive.month;
      for (var monthIndex = fromMonthIndex; monthIndex <= toMonthIndex; monthIndex++) {
        final diff = monthIndex - firstMonthIndex;
        if (diff < 0 || diff >= plan.months) {
          continue;
        }
        final year = monthIndex ~/ 12;
        final month = monthIndex % 12;
        final monthFixed = month == 0 ? 12 : month;
        final yearFixed = month == 0 ? year - 1 : year;
        final installmentDate = DateTime(yearFixed, monthFixed, 1);
        if (installmentDate.isBefore(fromDate) || installmentDate.isAfter(toInclusive)) {
          continue;
        }
        installmentDatesByPaymentId['${plan.paymentId}|$yearFixed|$monthFixed'] =
            installmentDate;
      }
    }

    return _buildFromPayments(
      allPayments: allPayments,
      doctorName: doctorName,
      isInstallmentInScope: (plan) {
        final firstMonthIndex = plan.startDate.year * 12 + plan.startDate.month;
        final fromMonthIndex = fromDate.year * 12 + fromDate.month;
        final toMonthIndex = toInclusive.year * 12 + toInclusive.month;
        for (var monthIndex = fromMonthIndex; monthIndex <= toMonthIndex; monthIndex++) {
          final diff = monthIndex - firstMonthIndex;
          if (diff < 0 || diff >= plan.months) {
            continue;
          }
          final year = monthIndex ~/ 12;
          final month = monthIndex % 12;
          final monthFixed = month == 0 ? 12 : month;
          final yearFixed = month == 0 ? year - 1 : year;
          if (installmentDatesByPaymentId.containsKey('${plan.paymentId}|$yearFixed|$monthFixed')) {
            return true;
          }
        }
        return false;
      },
      installmentDateProvider: (plan) {
        // For a date-range report we emit one row per active month within range.
        // The concrete dates are expanded in _buildFromPayments below.
        return DateTime(fromDate.year, fromDate.month, 1);
      },
      rangeFrom: fromDate,
      rangeToInclusive: toInclusive,
    );
  }

  Future<MonthlyReportResult> _buildFromPayments({
    required List<XanthusPaymentRow> allPayments,
    required String doctorName,
    required bool Function(RafidainInstallmentPlan plan) isInstallmentInScope,
    required DateTime Function(RafidainInstallmentPlan plan) installmentDateProvider,
    DateTime? rangeFrom,
    DateTime? rangeToInclusive,
  }) async {
    final plans = await _installmentPlanRepository.loadPlans();
    final plannedIds = plans.map((plan) => plan.paymentId).toSet();

    final regularRows = allPayments
        .where((payment) => !payment.isRafidainInstallment)
        .map(_toRegularRow)
        .toList();

    final pendingRafidain = allPayments
        .where(
          (payment) =>
              payment.isRafidainInstallment &&
              !plannedIds.contains(payment.paymentId),
        )
        .toList();

    final installmentRows = <DoctorMonthlyPaymentRow>[];
    for (final plan in plans) {
      if (plan.treatmentDoctor.trim() != doctorName.trim()) {
        continue;
      }

      if (rangeFrom == null || rangeToInclusive == null) {
        if (!isInstallmentInScope(plan)) {
          continue;
        }
        installmentRows.add(
          DoctorMonthlyPaymentRow(
            paymentId: plan.paymentId,
            invoiceId: plan.invoiceId,
            patientName: plan.patientName,
            phoneNumber: plan.phoneNumber,
            amount: plan.monthlyAmount,
            paymentDate: installmentDateProvider(plan),
            paymentMethod: plan.localOnly
                ? 'قسط محلي - داخل التطبيق'
                : 'رافدين - قسط شهري',
            treatmentDoctor: plan.treatmentDoctor,
            isRafidainInstallmentSource: true,
            installmentMonths: plan.months,
            monthlyInstallmentAmount: plan.monthlyAmount,
          ),
        );
        continue;
      }

      final firstMonthIndex = plan.startDate.year * 12 + plan.startDate.month;
      final fromMonthIndex = rangeFrom.year * 12 + rangeFrom.month;
      final toMonthIndex = rangeToInclusive.year * 12 + rangeToInclusive.month;

      for (var monthIndex = fromMonthIndex; monthIndex <= toMonthIndex; monthIndex++) {
        final diff = monthIndex - firstMonthIndex;
        if (diff < 0 || diff >= plan.months) {
          continue;
        }
        final year = monthIndex ~/ 12;
        final month = monthIndex % 12;
        final monthFixed = month == 0 ? 12 : month;
        final yearFixed = month == 0 ? year - 1 : year;
        final installmentDate = DateTime(yearFixed, monthFixed, 1);
        if (installmentDate.isBefore(rangeFrom) ||
            installmentDate.isAfter(rangeToInclusive)) {
          continue;
        }
        installmentRows.add(
          DoctorMonthlyPaymentRow(
            paymentId: plan.paymentId,
            invoiceId: plan.invoiceId,
            patientName: plan.patientName,
            phoneNumber: plan.phoneNumber,
            amount: plan.monthlyAmount,
            paymentDate: installmentDate,
            paymentMethod: plan.localOnly
                ? 'قسط محلي - داخل التطبيق'
                : 'رافدين - قسط شهري',
            treatmentDoctor: plan.treatmentDoctor,
            isRafidainInstallmentSource: true,
            installmentMonths: plan.months,
            monthlyInstallmentAmount: plan.monthlyAmount,
          ),
        );
      }
    }

    final allRows = <DoctorMonthlyPaymentRow>[
      ...regularRows,
      ...installmentRows,
    ]..sort((a, b) => a.paymentDate.compareTo(b.paymentDate));

    final total = allRows.fold<double>(0, (sum, row) => sum + row.amount);
    return MonthlyReportResult(
      rows: allRows,
      pendingRafidainPayments: pendingRafidain,
      totalAmount: total,
    );
  }

  DoctorMonthlyPaymentRow _toRegularRow(XanthusPaymentRow payment) {
    return DoctorMonthlyPaymentRow(
      paymentId: payment.paymentId,
      invoiceId: payment.invoiceId,
      patientName: payment.patientName,
      phoneNumber: payment.phoneNumber,
      amount: payment.amount,
      paymentDate: payment.paymentDate,
      paymentMethod: payment.paymentMethodLabel,
      treatmentDoctor: payment.treatmentDoctor,
      isRafidainInstallmentSource: false,
    );
  }
}
