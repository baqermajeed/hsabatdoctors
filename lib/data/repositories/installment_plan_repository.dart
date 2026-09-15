import '../../core/config/plans_api_config.dart';
import '../../domain/entities/rafidain_installment_plan.dart';
import '../local/hsabat_local_store.dart';
import '../remote/installment_plans_api_client.dart';
import '../services/windows_daily_backup_scheduler.dart';
import 'doctor_selection_repository.dart';
import 'plans_api_settings_repository.dart';

/// مصدر الاستخدام اليومي: محلي (ملف ثابت).
/// السيرفر: باك أب — يومي عبر Windows Scheduler حتى لو التطبيق مغلق.
class InstallmentPlanRepository {
  InstallmentPlanRepository({
    InstallmentPlansApiClient? apiClient,
    PlansApiSettingsRepository? settingsRepository,
    DoctorSelectionRepository? doctorSelectionRepository,
    HsabatLocalStore? localStore,
    WindowsDailyBackupScheduler? scheduler,
  }) : _apiClient = apiClient ?? InstallmentPlansApiClient(),
       _settingsRepository = settingsRepository ?? PlansApiSettingsRepository(),
       _doctorSelectionRepository =
           doctorSelectionRepository ?? DoctorSelectionRepository(),
       _localStore = localStore ?? HsabatLocalStore(),
       _scheduler = scheduler;

  static const _dailyBackupInterval = Duration(hours: 24);

  final InstallmentPlansApiClient _apiClient;
  final PlansApiSettingsRepository _settingsRepository;
  final DoctorSelectionRepository _doctorSelectionRepository;
  final HsabatLocalStore _localStore;
  WindowsDailyBackupScheduler? _scheduler;

  WindowsDailyBackupScheduler get scheduler =>
      _scheduler ??= WindowsDailyBackupScheduler(_localStore);

  HsabatLocalStore get localStore => _localStore;

  Future<List<RafidainInstallmentPlan>> loadPlans() async {
    return _localStore.loadPlans();
  }

  Future<void> savePlan(RafidainInstallmentPlan plan) async {
    final current = await _localStore.loadPlans();
    final withoutSamePayment =
        current.where((item) => item.paymentId != plan.paymentId).toList();
    withoutSamePayment.add(plan);
    await _localStore.savePlans(withoutSamePayment);

    final config = await _settingsRepository.load();
    if (!config.isConfigured) {
      return;
    }
    try {
      await _apiClient.upsertPlan(config, plan);
    } catch (_) {
      // يُعوَّض بالمهمة اليومية / الرفع اليدوي.
    }
  }

  Future<int> backupToServer({PlansApiConfig? config}) async {
    final resolved = config ?? await _settingsRepository.load();
    if (!resolved.isConfigured) {
      throw Exception(
        'أدخل عنوان السيرفر ومفتاح API من الإعدادات قبل رفع النسخة.',
      );
    }

    await _localStore.saveBackupConfig(resolved);
    final local = await _localStore.loadPlans();
    final doctorSelection = await _doctorSelectionRepository.exportBackupPayload();
    int count;
    try {
      count = await _apiClient.uploadAppStateBackup(
        resolved,
        plans: local,
        doctorSelection: doctorSelection,
      );
    } catch (_) {
      // fallback للتوافق مع نسخ backend القديمة.
      count = await _apiClient.uploadBackup(resolved, local);
    }
    final now = DateTime.now().toUtc();
    await _localStore.saveLastBackupAt(now);
    await _settingsRepository.saveLastBackupAt(now);
    return count;
  }

  Future<int> restoreFromServer({PlansApiConfig? config}) async {
    final resolved = config ?? await _settingsRepository.load();
    if (!resolved.isConfigured) {
      throw Exception(
        'أدخل عنوان السيرفر ومفتاح API من الإعدادات قبل الاستعادة.',
      );
    }

    List<RafidainInstallmentPlan> remote;
    Map<String, dynamic>? doctorSelection;
    try {
      final appState = await _apiClient.fetchAppStateBackup(resolved);
      final plansRaw = appState['plans'];
      if (plansRaw is List) {
        remote = plansRaw
            .whereType<Map>()
            .map((item) => item.map((k, v) => MapEntry(k.toString(), v)))
            .map(RafidainInstallmentPlan.fromMap)
            .toList(growable: false);
      } else {
        remote = const [];
      }
      final selectionRaw = appState['doctorSelection'];
      if (selectionRaw is Map<String, dynamic>) {
        doctorSelection = selectionRaw;
      } else if (selectionRaw is Map) {
        doctorSelection = selectionRaw.map((k, v) => MapEntry(k.toString(), v));
      }
    } catch (_) {
      remote = await _apiClient.fetchPlans(resolved);
    }

    final local = await _localStore.loadPlans();
    final localOnlyById = <String, RafidainInstallmentPlan>{
      for (final plan in local.where((plan) => plan.localOnly))
        plan.paymentId: plan,
    };
    final merged = <RafidainInstallmentPlan>[
      ...remote.where((plan) => !localOnlyById.containsKey(plan.paymentId)),
      ...localOnlyById.values,
    ];
    await _localStore.savePlans(merged);
    if (doctorSelection != null) {
      await _doctorSelectionRepository.restoreFromBackupPayload(doctorSelection);
    }
    return remote.length;
  }

  Future<bool> maybeBackupDailyIfDue() async {
    final config = await _settingsRepository.load();
    if (!config.isConfigured) {
      return false;
    }

    final last = await lastBackupAt();
    final now = DateTime.now().toUtc();
    if (last != null && now.difference(last) < _dailyBackupInterval) {
      return false;
    }

    await backupToServer(config: config);
    return true;
  }

  /// يفعّل مهمة Windows اليومية + يحفظ إعدادات الرفع للسكربت.
  Future<void> enableAutomaticDailyBackup({
    PlansApiConfig? config,
    String time = '02:00',
  }) async {
    final resolved = config ?? await _settingsRepository.load();
    if (!resolved.isConfigured) {
      throw Exception('أدخل عنوان السيرفر ومفتاح API أولاً.');
    }
    await _settingsRepository.save(resolved);
    await _localStore.saveBackupConfig(resolved);
    await scheduler.enableDailyTask(time: time);
  }

  Future<bool> isAutomaticDailyBackupEnabled() =>
      scheduler.isDailyTaskRegistered();

  Future<DateTime?> lastBackupAt() async {
    final fromFile = await _localStore.loadLastBackupAt();
    if (fromFile != null) {
      return fromFile;
    }
    return _settingsRepository.loadLastBackupAt();
  }
}
