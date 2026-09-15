import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/config/database_config.dart';
import '../../core/config/plans_api_config.dart';
import '../../core/database/xanthus_readonly_client.dart';
import '../../data/exporters/doctor_report_word_exporter.dart';
import '../../data/models/payment_transaction.dart';
import '../../data/models/xanthus_payment_row.dart';
import '../../data/remote/installment_plans_api_client.dart';
import '../../data/repositories/doctor_selection_repository.dart';
import '../../data/repositories/installment_plan_repository.dart';
import '../../data/repositories/monthly_report_repository.dart';
import '../../data/repositories/payment_repository.dart';
import '../../data/repositories/plans_api_settings_repository.dart';
import '../../domain/entities/doctor_monthly_payment_row.dart';
import '../../domain/services/monthly_report_service.dart';
import '../../domain/services/tamweel_distribution_service.dart';

enum ReportPeriodMode {
  monthly,
  dateRange,
}

class MainDashboardController extends ChangeNotifier {
  MainDashboardController() : _client = XanthusReadonlyClient() {
    _attachRepositories(_client);
  }

  final TextEditingController serverController = TextEditingController(text: 'localhost');
  final TextEditingController databaseController =
      TextEditingController(text: 'XanthusClinicsData');
  final TextEditingController portController = TextEditingController(text: '1433');
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController doctorPercentController = TextEditingController(text: '50');
  final TextEditingController tarakeebController = TextEditingController(text: '0');
  final TextEditingController tamweelController = TextEditingController(text: '0');
  final TextEditingController totalTamweelController = TextEditingController(text: '0');
  final TextEditingController plansApiBaseUrlController = TextEditingController();
  final TextEditingController plansApiKeyController = TextEditingController();
  final TextEditingController localPlanPatientNameController =
      TextEditingController();
  final TextEditingController localPlanPhoneController = TextEditingController();
  final TextEditingController localPlanAmountController = TextEditingController();
  final TextEditingController localPlanMonthsController =
      TextEditingController(text: '12');
  final TextEditingController localPlanInvoiceController =
      TextEditingController();

  final XanthusReadonlyClient _client;
  final DoctorSelectionRepository _selectionRepository = DoctorSelectionRepository();
  final PlansApiSettingsRepository _plansApiSettingsRepository =
      PlansApiSettingsRepository();
  final InstallmentPlansApiClient _plansApiClient = InstallmentPlansApiClient();
  final InstallmentPlanRepository _installmentPlanRepository =
      InstallmentPlanRepository();
  final TamweelDistributionService _tamweelDistribution =
      const TamweelDistributionService();
  late PaymentRepository _paymentRepository;
  late MonthlyReportService _reportService;
  final DoctorReportWordExporter _wordExporter = DoctorReportWordExporter();

  final Map<String, TextEditingController> pendingMonthsControllers = {};

  SqlAuthMode authMode = SqlAuthMode.windows;
  bool isBusy = false;
  String statusMessage = 'لم يتم اختبار الاتصال بعد.';
  String lastPlansBackupLabel = 'لم يُرفع باك أب بعد.';
  String autoBackupStatusLabel = 'المهمة اليومية: غير مفعّلة';
  List<PaymentTransaction> samplePayments = const [];

  List<String> officialDoctors = const [];
  Set<String> selectedDoctorNames = <String>{};
  String? ownerDoctorName;
  Map<String, double> doctorNetAmounts = const {};
  Map<String, double> tamweelShares = const {};
  String? selectedDoctor;
  int selectedMonth = DateTime.now().month;
  int selectedYear = DateTime.now().year;
  DateTime localPlanFirstInstallmentDate = DateTime(
    DateTime.now().year,
    DateTime.now().month + 1,
    1,
  );
  ReportPeriodMode periodMode = ReportPeriodMode.monthly;
  DateTime rangeFrom = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime rangeTo = DateTime.now();

  List<DoctorMonthlyPaymentRow> reportRows = const [];
  List<XanthusPaymentRow> pendingRafidain = const [];
  double monthlyTotal = 0;
  double _appliedTarakeebAmount = 0;
  double _appliedTamweelAmount = 0;
  Timer? _backupWatchdog;

  List<String> get activeDoctors {
    if (selectedDoctorNames.isEmpty) {
      return const [];
    }
    return officialDoctors
        .where((name) => selectedDoctorNames.contains(name))
        .toList(growable: false);
  }

  bool isDoctorSelected(String doctorName) => selectedDoctorNames.contains(doctorName);

  bool isOwnerDoctor(String doctorName) =>
      ownerDoctorName != null && ownerDoctorName == doctorName;

  double tamweelShareFor(String doctorName) => tamweelShares[doctorName] ?? 0;

  Future<void> initialize() async {
    await _loadSelectionPreferences();
    await _selectionRepository.ensureSnapshotSynced();
    await _loadDoctors();
    unawaited(_runSilentDailyBackup());
    _startBackupWatchdog();
  }

  void _startBackupWatchdog() {
    _backupWatchdog?.cancel();
    // إعادة محاولة مستمرة أثناء عمل التطبيق (كل 30 دقيقة).
    _backupWatchdog = Timer.periodic(const Duration(minutes: 30), (_) {
      unawaited(_runSilentDailyBackup());
    });
  }

  Future<void> _runSilentDailyBackup() async {
    try {
      final didBackup = await _installmentPlanRepository.maybeBackupDailyIfDue();
      if (!didBackup) {
        return;
      }
      final at = await _installmentPlanRepository.lastBackupAt();
      lastPlansBackupLabel = at == null
          ? 'آخر باك أب: اليوم'
          : 'آخر باك أب: ${_formatBackupStamp(at.toLocal())}';
      notifyListeners();
    } catch (_) {
      // الاستخدام اليومي لا يعتمد على السيرفر.
    }
  }

  void setAuthMode(SqlAuthMode value) {
    authMode = value;
    notifyListeners();
  }

  Future<void> toggleDoctorSelection(String doctorName, bool selected) async {
    final name = doctorName.trim();
    if (name.isEmpty) {
      return;
    }

    final next = Set<String>.from(selectedDoctorNames);
    if (selected) {
      next.add(name);
    } else {
      next.remove(name);
      if (ownerDoctorName == name) {
        ownerDoctorName = null;
        await _selectionRepository.saveOwnerDoctor(null);
      }
    }
    selectedDoctorNames = next;
    await _selectionRepository.saveSelectedDoctors(selectedDoctorNames);
    _syncSelectedDoctorWithActiveList();
    notifyListeners();
  }

  Future<void> setOwnerDoctor(String? doctorName) async {
    final name = doctorName?.trim();
    if (name == null || name.isEmpty) {
      ownerDoctorName = null;
      await _selectionRepository.saveOwnerDoctor(null);
      notifyListeners();
      return;
    }

    ownerDoctorName = name;
    if (!selectedDoctorNames.contains(name)) {
      selectedDoctorNames = {...selectedDoctorNames, name};
      await _selectionRepository.saveSelectedDoctors(selectedDoctorNames);
    }
    await _selectionRepository.saveOwnerDoctor(name);
    _syncSelectedDoctorWithActiveList();
    notifyListeners();
  }

  Future<void> saveTotalTamweelAmount() async {
    final amount = double.tryParse(totalTamweelController.text.trim()) ?? 0;
    await _selectionRepository.saveTotalTamweel(amount);
    statusMessage = 'تم حفظ إجمالي أجور التمويل.';
    notifyListeners();
  }

  Future<void> savePlansApiSettings() async {
    final config = PlansApiConfig(
      baseUrl: plansApiBaseUrlController.text.trim(),
      apiKey: plansApiKeyController.text.trim(),
    );
    await _plansApiSettingsRepository.save(config);
    if (config.isConfigured) {
      await _installmentPlanRepository.localStore.saveBackupConfig(config);
      try {
        await _installmentPlanRepository.enableAutomaticDailyBackup(
          config: config,
        );
        autoBackupStatusLabel =
            'المهمة اليومية: مفعّلة (كل يوم 02:00 حتى لو التطبيق مغلق)';
        statusMessage =
            'تم الحفظ وتفعيل الرفع اليومي التلقائي عبر Windows Scheduler.';
      } catch (error) {
        autoBackupStatusLabel = 'المهمة اليومية: تعذّر التفعيل';
        statusMessage =
            'حُفظت الإعدادات، لكن فشل تفعيل المهمة التلقائية: $error';
      }
    } else {
      autoBackupStatusLabel = 'المهمة اليومية: غير مفعّلة';
      statusMessage = 'تم الحفظ (السيرفر غير مفعّل — التخزين المحلي يعمل فقط).';
    }
    notifyListeners();
  }

  Future<void> enableAutomaticDailyBackup() async {
    final config = PlansApiConfig(
      baseUrl: plansApiBaseUrlController.text.trim(),
      apiKey: plansApiKeyController.text.trim(),
    );
    if (!config.isConfigured) {
      statusMessage = 'أدخل عنوان السيرفر ومفتاح API أولاً.';
      notifyListeners();
      return;
    }

    _setBusy('جاري تفعيل الرفع اليومي التلقائي...');
    try {
      await _plansApiSettingsRepository.save(config);
      await _installmentPlanRepository.enableAutomaticDailyBackup(
        config: config,
      );
      autoBackupStatusLabel =
          'المهمة اليومية: مفعّلة (كل يوم 02:00 حتى لو التطبيق مغلق)';
      statusMessage =
          'تم تفعيل باك أب يومي تلقائي عبر Windows Task Scheduler.';
    } catch (error) {
      statusMessage = 'فشل تفعيل المهمة التلقائية: $error';
    } finally {
      _setIdle();
    }
  }

  Future<void> testPlansApiConnection() async {
    final config = PlansApiConfig(
      baseUrl: plansApiBaseUrlController.text.trim(),
      apiKey: plansApiKeyController.text.trim(),
    );
    if (!config.isConfigured) {
      statusMessage = 'أدخل عنوان السيرفر ومفتاح API أولاً.';
      notifyListeners();
      return;
    }

    _setBusy('جاري اختبار سيرفر النسخ الاحتياطي...');
    try {
      await _plansApiSettingsRepository.save(config);
      await _installmentPlanRepository.localStore.saveBackupConfig(config);
      await _plansApiClient.ping(config);
      statusMessage =
          'الاتصال ناجح. العمل اليومي محلي والسيرفر للنسخ الاحتياطي.';
    } catch (error) {
      statusMessage = 'فشل اتصال السيرفر: $error';
    } finally {
      _setIdle();
    }
  }

  Future<void> backupPlansToServer() async {
    final config = PlansApiConfig(
      baseUrl: plansApiBaseUrlController.text.trim(),
      apiKey: plansApiKeyController.text.trim(),
    );
    if (!config.isConfigured) {
      statusMessage = 'أدخل عنوان السيرفر ومفتاح API أولاً.';
      notifyListeners();
      return;
    }

    _setBusy('جاري رفع نسخة احتياطية للخطط إلى السيرفر...');
    try {
      await _plansApiSettingsRepository.save(config);
      final count =
          await _installmentPlanRepository.backupToServer(config: config);
      final at = await _installmentPlanRepository.lastBackupAt();
      lastPlansBackupLabel = at == null
          ? 'آخر باك أب: الآن'
          : 'آخر باك أب: ${_formatBackupStamp(at.toLocal())}';
      statusMessage = 'تم رفع باك أب لـ $count خطة أقساط إلى السيرفر.';
    } catch (error) {
      statusMessage = 'فشل رفع النسخة الاحتياطية: $error';
    } finally {
      _setIdle();
    }
  }

  Future<void> restorePlansFromServer() async {
    final config = PlansApiConfig(
      baseUrl: plansApiBaseUrlController.text.trim(),
      apiKey: plansApiKeyController.text.trim(),
    );
    if (!config.isConfigured) {
      statusMessage = 'أدخل عنوان السيرفر ومفتاح API أولاً.';
      notifyListeners();
      return;
    }

    _setBusy('جاري استعادة خطط الأقساط من السيرفر...');
    try {
      await _plansApiSettingsRepository.save(config);
      final count =
          await _installmentPlanRepository.restoreFromServer(config: config);
      await _loadSelectionPreferences();
      _syncSelectedDoctorWithActiveList();
      statusMessage = count == 0
          ? 'لا توجد خطط على السيرفر للاستعادة.'
          : 'تمت استعادة $count خطة إلى التخزين المحلي.';
    } catch (error) {
      statusMessage = 'فشل الاستعادة من السيرفر: $error';
    } finally {
      _setIdle();
    }
  }

  String _formatBackupStamp(DateTime at) {
    final d =
        '${at.year}-${at.month.toString().padLeft(2, '0')}-${at.day.toString().padLeft(2, '0')}';
    final t =
        '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
    return '$d $t';
  }

  Future<void> recalculateTamweelDistribution() async {
    if (!_client.isConnected) {
      statusMessage = 'الرجاء اختبار الاتصال أولاً.';
      notifyListeners();
      return;
    }
    if (activeDoctors.isEmpty) {
      statusMessage = 'اختر الأطباء من الإعدادات أولاً.';
      notifyListeners();
      return;
    }

    _setBusy('جاري حساب توزيع أجور التمويل على الأطباء المختارين...');
    try {
      final totalTamweel = double.tryParse(totalTamweelController.text.trim()) ?? 0;
      await _selectionRepository.saveTotalTamweel(totalTamweel);

      final nets = <String, double>{};
      for (final doctorName in activeDoctors) {
        final result = periodMode == ReportPeriodMode.monthly
            ? await _reportService.buildMonthlyReport(
                year: selectedYear,
                month: selectedMonth,
                doctorName: doctorName,
              )
            : await _reportService.buildRangeReport(
                from: rangeFrom,
                toInclusive: rangeTo,
                doctorName: doctorName,
              );
        nets[doctorName] = result.totalAmount * doctorPercent / 100;
      }

      doctorNetAmounts = nets;
      tamweelShares = _tamweelDistribution.distribute(
        totalTamweel: totalTamweel,
        selectedDoctors: activeDoctors,
        ownerDoctor: ownerDoctorName,
        doctorNetAmounts: nets,
      );

      if (selectedDoctor != null) {
        _applyStoredTamweelShare(selectedDoctor!);
      }

      statusMessage =
          'تم توزيع أجور التمويل على ${activeDoctors.length} طبيب (75% مالك + 25% الباقون).';
    } catch (error) {
      statusMessage = 'فشل حساب توزيع التمويل: $error';
    } finally {
      _setIdle();
    }
  }

  void setDoctor(String? value, {bool notify = true}) {
    final doctorChanged = selectedDoctor != value;
    selectedDoctor = value;
    if (doctorChanged) {
      _resetDoctorDeductions();
      if (value != null) {
        _applyStoredTamweelShare(value);
      }
    }
    if (notify) {
      notifyListeners();
    }
  }

  void refreshUi() {
    notifyListeners();
  }

  void setMonth(int value) {
    selectedMonth = value;
    notifyListeners();
  }

  void setYear(int value) {
    selectedYear = value;
    notifyListeners();
  }

  void setPeriodMode(ReportPeriodMode mode) {
    periodMode = mode;
    notifyListeners();
  }

  void setRangeFrom(DateTime date) {
    rangeFrom = DateTime(date.year, date.month, date.day);
    if (rangeFrom.isAfter(rangeTo)) {
      rangeTo = rangeFrom;
    }
    notifyListeners();
  }

  void setRangeTo(DateTime date) {
    rangeTo = DateTime(date.year, date.month, date.day);
    if (rangeTo.isBefore(rangeFrom)) {
      rangeFrom = rangeTo;
    }
    notifyListeners();
  }

  double get doctorPercent => double.tryParse(doctorPercentController.text.trim()) ?? 50;
  double get doctorAmount => monthlyTotal * doctorPercent / 100;
  double get tarakeebAmountInput => double.tryParse(tarakeebController.text.trim()) ?? 0;
  double get tamweelAmountInput => double.tryParse(tamweelController.text.trim()) ?? 0;
  double get appliedTarakeebAmount => _appliedTarakeebAmount;
  double get appliedTamweelAmount {
    if (selectedDoctor == null || !isDoctorSelected(selectedDoctor!)) {
      return 0;
    }
    final share = tamweelShareFor(selectedDoctor!);
    if (share > 0) {
      return share;
    }
    return _appliedTamweelAmount;
  }

  double get amountAfterTamweel => doctorAmount - appliedTamweelAmount;
  double get finalDoctorAmount => amountAfterTamweel - _appliedTarakeebAmount;

  void applyTarakeebFee() {
    _appliedTarakeebAmount = tarakeebAmountInput;
    notifyListeners();
  }

  void applyTamweelFee() {
    if (selectedDoctor == null || !isDoctorSelected(selectedDoctor!)) {
      statusMessage = 'هذا الطبيب غير مختار لحساب التمويل.';
      notifyListeners();
      return;
    }
    _appliedTamweelAmount = tamweelAmountInput;
    notifyListeners();
  }

  void clearAppliedDeductions() {
    _appliedTarakeebAmount = 0;
    tarakeebController.text = '0';
    if (selectedDoctor != null) {
      _applyStoredTamweelShare(selectedDoctor!);
    } else {
      _appliedTamweelAmount = 0;
      tamweelController.text = '0';
    }
    notifyListeners();
  }

  String get reportPeriodLabel {
    if (periodMode == ReportPeriodMode.monthly) {
      return 'شهر $selectedMonth/$selectedYear';
    }
    final from =
        '${rangeFrom.year}-${rangeFrom.month.toString().padLeft(2, '0')}-${rangeFrom.day.toString().padLeft(2, '0')}';
    final to =
        '${rangeTo.year}-${rangeTo.month.toString().padLeft(2, '0')}-${rangeTo.day.toString().padLeft(2, '0')}';
    return 'من $from إلى $to';
  }

  Future<String?> exportDoctorReportWord() async {
    if (selectedDoctor == null || selectedDoctor!.trim().isEmpty) {
      statusMessage = 'الرجاء اختيار طبيب أولاً.';
      notifyListeners();
      return null;
    }
    if (reportRows.isEmpty) {
      statusMessage = 'لا توجد بيانات للتصدير. أنشئ التقرير أولاً.';
      notifyListeners();
      return null;
    }

    _setBusy('جاري تصدير تقرير Word إلى التنزيلات...');
    try {
      final result = await _wordExporter.export(
        doctorName: selectedDoctor!,
        periodLabel: reportPeriodLabel,
        rows: reportRows,
        totalAmount: monthlyTotal,
        doctorPercent: doctorPercent,
        doctorAmount: doctorAmount,
        appliedTarakeebAmount: appliedTarakeebAmount,
        appliedTamweelAmount: appliedTamweelAmount,
        finalDoctorAmount: finalDoctorAmount,
      );

      statusMessage = 'تم حفظ التقرير في التنزيلات:\n${result.filePath}';
      return result.filePath;
    } catch (error) {
      statusMessage = 'فشل تصدير Word: $error';
      return null;
    } finally {
      _setIdle();
    }
  }

  void _resetDoctorDeductions() {
    _appliedTarakeebAmount = 0;
    _appliedTamweelAmount = 0;
    tarakeebController.text = '0';
    tamweelController.text = '0';
  }

  Future<void> testConnection() async {
    _setBusy('جاري اختبار الاتصال...');
    try {
      _client.disconnect();
      await _client.connect(_buildConfig());
      await refreshDoctorsFromDatabase(silent: true);
      statusMessage = 'Connection successful';
    } catch (error) {
      statusMessage = 'فشل الاتصال: $error';
    } finally {
      _setIdle();
    }
  }

  Future<void> refreshDoctorsFromDatabase({bool silent = false}) async {
    if (!_client.isConnected) {
      if (!silent) {
        statusMessage = 'الرجاء اختبار الاتصال أولاً.';
        notifyListeners();
      }
      return;
    }

    if (!silent) {
      _setBusy('جاري تحميل قائمة الأطباء من قاعدة البيانات...');
    }

    try {
      final doctors = await _reportService.loadDoctorsFromDatabase();
      officialDoctors = doctors;
      selectedDoctorNames = selectedDoctorNames.intersection(doctors.toSet());
      if (ownerDoctorName != null && !doctors.contains(ownerDoctorName)) {
        ownerDoctorName = null;
        await _selectionRepository.saveOwnerDoctor(null);
      }
      await _selectionRepository.saveSelectedDoctors(selectedDoctorNames);
      _syncSelectedDoctorWithActiveList();
      if (!silent) {
        statusMessage =
            'تم تحميل ${doctors.length} طبيب · المختارون للعرض: ${activeDoctors.length}';
      }
    } catch (error) {
      if (!silent) {
        statusMessage = 'فشل تحميل قائمة الأطباء: $error';
      }
    } finally {
      if (!silent) {
        _setIdle();
      } else {
        notifyListeners();
      }
    }
  }

  Future<void> loadPaymentSample() async {
    if (!_client.isConnected) {
      statusMessage = 'الرجاء اختبار الاتصال أولاً.';
      notifyListeners();
      return;
    }

    _setBusy('جاري تحميل عينة الدفعات...');
    try {
      final sample = await _paymentRepository.fetchPaymentSample(limit: 30);
      samplePayments = sample;
      statusMessage = 'تم تحميل ${sample.length} سجل دفعات.';
    } catch (error) {
      statusMessage = 'تعذر تحميل الدفعات: $error';
    } finally {
      _setIdle();
    }
  }

  Future<void> generateMonthlyReport() async {
    if (!_client.isConnected) {
      statusMessage = 'الرجاء اختبار الاتصال أولاً.';
      notifyListeners();
      return;
    }
    if (selectedDoctor == null || selectedDoctor!.trim().isEmpty) {
      statusMessage = 'الرجاء اختيار طبيب من القائمة الرسمية.';
      notifyListeners();
      return;
    }
    if (!isDoctorSelected(selectedDoctor!)) {
      statusMessage = 'هذا الطبيب غير مفعّل في الإعدادات.';
      notifyListeners();
      return;
    }

    _setBusy('جاري توليد التقرير الشهري...');
    try {
      final debugYear = selectedYear;
      final debugMonth = selectedMonth;
      final debugDoctor = selectedDoctor!;
      final result = periodMode == ReportPeriodMode.monthly
          ? await _reportService.buildMonthlyReport(
              year: debugYear,
              month: debugMonth,
              doctorName: debugDoctor,
            )
          : await _reportService.buildRangeReport(
              from: rangeFrom,
              toInclusive: rangeTo,
              doctorName: debugDoctor,
            );

      for (final payment in result.pendingRafidainPayments) {
        pendingMonthsControllers.putIfAbsent(
          payment.paymentId,
          () => TextEditingController(text: '12'),
        );
      }

      reportRows = result.rows;
      pendingRafidain = result.pendingRafidainPayments;
      monthlyTotal = result.totalAmount;
      _applyStoredTamweelShare(debugDoctor);
      statusMessage = periodMode == ReportPeriodMode.monthly
          ? 'تم توليد تقرير $debugMonth/$debugYear بنجاح'
          : 'تم توليد تقرير الفترة بنجاح';
    } catch (error) {
      statusMessage = 'فشل توليد التقرير: $error';
    } finally {
      _setIdle();
    }
  }

  Future<void> savePendingPlan(XanthusPaymentRow payment) async {
    final controller = pendingMonthsControllers[payment.paymentId];
    final months = int.tryParse(controller?.text.trim() ?? '') ?? 0;
    if (months < 1) {
      statusMessage = 'عدد الأشهر يجب أن يكون أكبر من صفر.';
      notifyListeners();
      return;
    }

    _setBusy('جاري حفظ خطة التقسيط...');
    try {
      await _reportService.saveInstallmentPlan(sourcePayment: payment, months: months);
      await generateMonthlyReport();
      statusMessage = 'تم حفظ خطة تقسيط الرافدين.';
    } catch (error) {
      statusMessage = 'تعذر حفظ الخطة: $error';
    } finally {
      _setIdle();
    }
  }

  Future<void> saveLocalOnlyInstallmentPlan() async {
    final doctor = selectedDoctor?.trim() ?? '';
    if (doctor.isEmpty) {
      statusMessage = 'اختر طبيبًا أولًا قبل إضافة قسط محلي.';
      notifyListeners();
      return;
    }

    final patientName = localPlanPatientNameController.text.trim();
    if (patientName.isEmpty) {
      statusMessage = 'أدخل اسم المريض.';
      notifyListeners();
      return;
    }

    final amount = double.tryParse(localPlanAmountController.text.trim()) ?? 0;
    if (amount <= 0) {
      statusMessage = 'أدخل مبلغًا صحيحًا أكبر من صفر.';
      notifyListeners();
      return;
    }

    final months = int.tryParse(localPlanMonthsController.text.trim()) ?? 0;
    if (months < 1) {
      statusMessage = 'عدد الأشهر يجب أن يكون أكبر من صفر.';
      notifyListeners();
      return;
    }

    _setBusy('جاري إضافة مريض أقساط محلي...');
    try {
      await _reportService.saveLocalOnlyInstallmentPlan(
        patientName: patientName,
        phoneNumber: localPlanPhoneController.text.trim(),
        treatmentDoctor: doctor,
        originalAmount: amount,
        months: months,
        firstInstallmentDate: localPlanFirstInstallmentDate,
        invoiceId: localPlanInvoiceController.text.trim(),
      );
      if (_client.isConnected) {
        await generateMonthlyReport();
        if (statusMessage.startsWith('فشل') || statusMessage.startsWith('تعذر')) {
          return;
        }
      }
      statusMessage =
          'تمت إضافة خطة أقساط محلية للمريض "$patientName" داخل التطبيق فقط.';
      localPlanPatientNameController.clear();
      localPlanPhoneController.clear();
      localPlanAmountController.clear();
      localPlanInvoiceController.clear();
      localPlanMonthsController.text = '12';
      localPlanFirstInstallmentDate = DateTime(
        DateTime.now().year,
        DateTime.now().month + 1,
        1,
      );
    } catch (error) {
      statusMessage = 'تعذر إضافة القسط المحلي: $error';
    } finally {
      _setIdle();
    }
  }

  void setLocalPlanFirstInstallmentDate(DateTime date) {
    localPlanFirstInstallmentDate = DateTime(date.year, date.month, 1);
    notifyListeners();
  }

  Future<void> _loadDoctors() async {
    officialDoctors = const [];
    selectedDoctor = null;
    notifyListeners();
  }

  Future<void> _loadSelectionPreferences() async {
    selectedDoctorNames = await _selectionRepository.loadSelectedDoctors();
    ownerDoctorName = await _selectionRepository.loadOwnerDoctor();
    final totalTamweel = await _selectionRepository.loadTotalTamweel();
    totalTamweelController.text = totalTamweel == 0
        ? '0'
        : totalTamweel.toStringAsFixed(totalTamweel.truncateToDouble() == totalTamweel ? 0 : 2);

    final plansApi = await _plansApiSettingsRepository.load();
    plansApiBaseUrlController.text = plansApi.baseUrl;
    plansApiKeyController.text = plansApi.apiKey;
    final lastBackup = await _installmentPlanRepository.lastBackupAt();
    lastPlansBackupLabel = lastBackup == null
        ? 'لم يُرفع باك أب بعد.'
        : 'آخر باك أب: ${_formatBackupStamp(lastBackup.toLocal())}';
    try {
      final enabled =
          await _installmentPlanRepository.isAutomaticDailyBackupEnabled();
      autoBackupStatusLabel = enabled
          ? 'المهمة اليومية: مفعّلة (كل يوم 02:00 حتى لو التطبيق مغلق)'
          : 'المهمة اليومية: غير مفعّلة';
    } catch (_) {
      autoBackupStatusLabel = 'المهمة اليومية: غير مفعّلة';
    }
  }

  void _syncSelectedDoctorWithActiveList() {
    final active = activeDoctors;
    if (active.isEmpty) {
      selectedDoctor = null;
      return;
    }
    if (selectedDoctor == null || !active.contains(selectedDoctor)) {
      selectedDoctor = active.first;
      _resetDoctorDeductions();
      _applyStoredTamweelShare(selectedDoctor!);
    }
  }

  void _applyStoredTamweelShare(String doctorName) {
    final share = tamweelShareFor(doctorName);
    if (share <= 0) {
      return;
    }
    tamweelController.text = share.toStringAsFixed(0);
    _appliedTamweelAmount = share;
  }

  void _setBusy(String message) {
    isBusy = true;
    statusMessage = message;
    notifyListeners();
  }

  void _setIdle() {
    isBusy = false;
    notifyListeners();
  }

  DatabaseConfig _buildConfig() {
    final parsedPort = int.tryParse(portController.text.trim()) ?? 1433;
    return DatabaseConfig.devDefaults().copyWith(
      server: serverController.text.trim(),
      database: databaseController.text.trim(),
      port: parsedPort,
      authMode: authMode,
      username: usernameController.text.trim(),
      password: passwordController.text.trim(),
    );
  }

  void _attachRepositories(XanthusReadonlyClient client) {
    _paymentRepository = PaymentRepository(client);
    _reportService = MonthlyReportService(
      reportRepository: MonthlyReportRepository(client),
      installmentPlanRepository: _installmentPlanRepository,
    );
  }

  @override
  void dispose() {
    _backupWatchdog?.cancel();
    _client.disconnect();
    serverController.dispose();
    databaseController.dispose();
    portController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    doctorPercentController.dispose();
    tarakeebController.dispose();
    tamweelController.dispose();
    totalTamweelController.dispose();
    plansApiBaseUrlController.dispose();
    plansApiKeyController.dispose();
    localPlanPatientNameController.dispose();
    localPlanPhoneController.dispose();
    localPlanAmountController.dispose();
    localPlanMonthsController.dispose();
    localPlanInvoiceController.dispose();
    for (final controller in pendingMonthsControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
}
