import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/plans_api_config.dart';

class PlansApiSettingsRepository {
  static const _baseUrlKey = 'plans_api_base_url_v1';
  static const _apiKeyKey = 'plans_api_key_v1';
  static const _lastBackupAtKey = 'plans_api_last_backup_at_v1';

  Future<PlansApiConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    return PlansApiConfig(
      baseUrl: prefs.getString(_baseUrlKey) ?? '',
      apiKey: prefs.getString(_apiKeyKey) ?? '',
    );
  }

  Future<void> save(PlansApiConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, config.baseUrl.trim());
    await prefs.setString(_apiKeyKey, config.apiKey.trim());
  }

  Future<DateTime?> loadLastBackupAt() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lastBackupAtKey);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw);
  }

  Future<void> saveLastBackupAt(DateTime at) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastBackupAtKey, at.toUtc().toIso8601String());
  }
}
