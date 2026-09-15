import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/plans_api_config.dart';
import '../../domain/entities/rafidain_installment_plan.dart';

/// تخزين محلي ثابت يمكن لمهمة Windows قراءته بدون فتح التطبيق.
class HsabatLocalStore {
  static const prefsPlansKey = 'rafidain_installment_plans_v1';
  static const folderName = 'hsabat';
  static const plansFileName = 'installment_plans.json';
  static const doctorSelectionFileName = 'doctor_selection.json';
  static const backupConfigFileName = 'backup_config.json';
  static const lastBackupFileName = 'last_backup_at.txt';
  static const backupScriptFileName = 'daily_backup.ps1';

  Future<Directory> dataDirectory() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, folderName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> plansFile() async {
    final dir = await dataDirectory();
    return File(p.join(dir.path, plansFileName));
  }

  Future<File> backupConfigFile() async {
    final dir = await dataDirectory();
    return File(p.join(dir.path, backupConfigFileName));
  }

  Future<File> doctorSelectionFile() async {
    final dir = await dataDirectory();
    return File(p.join(dir.path, doctorSelectionFileName));
  }

  Future<File> lastBackupFile() async {
    final dir = await dataDirectory();
    return File(p.join(dir.path, lastBackupFileName));
  }

  Future<File> backupScriptFile() async {
    final dir = await dataDirectory();
    return File(p.join(dir.path, backupScriptFileName));
  }

  Future<List<RafidainInstallmentPlan>> loadPlans() async {
    final file = await plansFile();
    if (await file.exists()) {
      final raw = await file.readAsString();
      final plans = RafidainInstallmentPlan.decodeList(raw);
      if (plans.isNotEmpty || raw.trim() == '[]') {
        return plans;
      }
    }

    // ترحيل من SharedPreferences إن وُجدت خطط قديمة.
    final prefs = await SharedPreferences.getInstance();
    final legacy = RafidainInstallmentPlan.decodeList(prefs.getString(prefsPlansKey));
    if (legacy.isNotEmpty) {
      await savePlans(legacy);
      return legacy;
    }
    return const [];
  }

  Future<void> savePlans(List<RafidainInstallmentPlan> plans) async {
    final file = await plansFile();
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(
        plans.map((plan) => plan.toMap()).toList(),
      ),
      flush: true,
    );

    // إبقاء نسخة قديمة متزامنة للتوافق.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsPlansKey, RafidainInstallmentPlan.encodeList(plans));
  }

  Future<void> saveBackupConfig(PlansApiConfig config) async {
    final plans = await plansFile();
    final doctorSelection = await doctorSelectionFile();
    final file = await backupConfigFile();
    final payload = {
      'baseUrl': config.baseUrl.trim().replaceAll(RegExp(r'/+$'), ''),
      'apiKey': config.apiKey.trim(),
      'plansPath': plans.path,
      'doctorSelectionPath': doctorSelection.path,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    };
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
      flush: true,
    );
  }

  Future<Map<String, dynamic>?> loadDoctorSelectionSnapshot() async {
    final file = await doctorSelectionFile();
    if (!await file.exists()) {
      return null;
    }
    final raw = (await file.readAsString()).trim();
    if (raw.isEmpty) {
      return null;
    }
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return decoded.map((k, v) => MapEntry(k.toString(), v));
    }
    return null;
  }

  Future<void> saveDoctorSelectionSnapshot(Map<String, dynamic> payload) async {
    final file = await doctorSelectionFile();
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
      flush: true,
    );
  }

  Future<DateTime?> loadLastBackupAt() async {
    final file = await lastBackupFile();
    if (await file.exists()) {
      final raw = (await file.readAsString()).trim();
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) {
        return parsed.toUtc();
      }
    }
    return null;
  }

  Future<void> saveLastBackupAt(DateTime at) async {
    final file = await lastBackupFile();
    await file.writeAsString(at.toUtc().toIso8601String(), flush: true);
  }
}
