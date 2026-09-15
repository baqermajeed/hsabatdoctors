import 'package:shared_preferences/shared_preferences.dart';

import '../local/hsabat_local_store.dart';

class DoctorSelectionRepository {
  DoctorSelectionRepository({HsabatLocalStore? localStore})
    : _localStore = localStore ?? HsabatLocalStore();

  static const _selectedKey = 'selected_doctors_v1';
  static const _ownerKey = 'owner_doctor_v1';
  static const _totalTamweelKey = 'total_tamweel_v1';

  final HsabatLocalStore _localStore;

  Future<Set<String>> loadSelectedDoctors() async {
    final prefs = await SharedPreferences.getInstance();
    final values = prefs.getStringList(_selectedKey) ?? const <String>[];
    return values.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
  }

  Future<void> saveSelectedDoctors(Set<String> doctors) async {
    final prefs = await SharedPreferences.getInstance();
    final sorted = doctors.map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
      ..sort();
    await prefs.setStringList(_selectedKey, sorted);
    await _saveSnapshotFromPrefs(prefs);
  }

  Future<String?> loadOwnerDoctor() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_ownerKey)?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }

  Future<void> saveOwnerDoctor(String? doctorName) async {
    final prefs = await SharedPreferences.getInstance();
    final value = doctorName?.trim();
    if (value == null || value.isEmpty) {
      await prefs.remove(_ownerKey);
      await _saveSnapshotFromPrefs(prefs);
      return;
    }
    await prefs.setString(_ownerKey, value);
    await _saveSnapshotFromPrefs(prefs);
  }

  Future<double> loadTotalTamweel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_totalTamweelKey) ?? 0;
  }

  Future<void> saveTotalTamweel(double amount) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_totalTamweelKey, amount < 0 ? 0 : amount);
    await _saveSnapshotFromPrefs(prefs);
  }

  Future<Map<String, dynamic>> exportBackupPayload() async {
    final selectedDoctors = await loadSelectedDoctors();
    final ownerDoctor = await loadOwnerDoctor();
    final totalTamweel = await loadTotalTamweel();
    return {
      'selectedDoctors': selectedDoctors.toList()..sort(),
      'ownerDoctor': ownerDoctor,
      'totalTamweel': totalTamweel,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    };
  }

  Future<void> restoreFromBackupPayload(Map<String, dynamic>? payload) async {
    if (payload == null) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();

    final selectedRaw = payload['selectedDoctors'];
    final selected = selectedRaw is List
        ? selectedRaw
              .map((item) => item.toString().trim())
              .where((name) => name.isNotEmpty)
              .toList()
        : const <String>[];
    selected.sort();
    await prefs.setStringList(_selectedKey, selected);

    final owner = payload['ownerDoctor']?.toString().trim();
    if (owner == null || owner.isEmpty) {
      await prefs.remove(_ownerKey);
    } else {
      await prefs.setString(_ownerKey, owner);
    }

    final total = _toDouble(payload['totalTamweel']);
    await prefs.setDouble(_totalTamweelKey, total < 0 ? 0 : total);

    await _saveSnapshotFromPrefs(prefs);
  }

  Future<Map<String, dynamic>?> loadSnapshotFromFile() async {
    return _localStore.loadDoctorSelectionSnapshot();
  }

  Future<void> ensureSnapshotSynced() async {
    final payload = await exportBackupPayload();
    await _localStore.saveDoctorSelectionSnapshot(payload);
  }

  Future<void> _saveSnapshotFromPrefs(SharedPreferences prefs) async {
    final selected = prefs.getStringList(_selectedKey) ?? const <String>[];
    final owner = prefs.getString(_ownerKey);
    final total = prefs.getDouble(_totalTamweelKey) ?? 0;
    final payload = <String, dynamic>{
      'selectedDoctors': selected,
      'ownerDoctor': owner,
      'totalTamweel': total,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    };
    await _localStore.saveDoctorSelectionSnapshot(payload);
  }

  double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
