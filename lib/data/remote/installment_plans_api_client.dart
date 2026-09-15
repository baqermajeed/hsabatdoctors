import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/plans_api_config.dart';
import '../../domain/entities/rafidain_installment_plan.dart';

class InstallmentPlansApiClient {
  InstallmentPlansApiClient({
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final http.Client _http;

  Future<List<RafidainInstallmentPlan>> fetchPlans(
    PlansApiConfig config, {
    String? doctor,
  }) async {
    _ensureConfigured(config);
    final query = <String, String>{};
    final doctorName = doctor?.trim();
    if (doctorName != null && doctorName.isNotEmpty) {
      query['doctor'] = doctorName;
    }

    final response = await _http
        .get(
          config.resolve('/api/plans', query.isEmpty ? null : query),
          headers: _headers(config),
        )
        .timeout(const Duration(seconds: 20));

    final body = _decodeMap(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_errorMessage(body, fallback: 'فشل جلب الخطط من السيرفر'));
    }

    final plansRaw = body['plans'];
    if (plansRaw is! List) {
      return const [];
    }

    return plansRaw
        .whereType<Map>()
        .map((item) => item.map((k, v) => MapEntry(k.toString(), v)))
        .map(RafidainInstallmentPlan.fromMap)
        .toList(growable: false);
  }

  Future<RafidainInstallmentPlan> upsertPlan(
    PlansApiConfig config,
    RafidainInstallmentPlan plan,
  ) async {
    _ensureConfigured(config);
    final response = await _http
        .post(
          config.resolve('/api/plans'),
          headers: {
            ..._headers(config),
            'Content-Type': 'application/json; charset=utf-8',
          },
          body: jsonEncode(plan.toMap()),
        )
        .timeout(const Duration(seconds: 20));

    final body = _decodeMap(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_errorMessage(body, fallback: 'فشل حفظ الخطة على السيرفر'));
    }

    final planRaw = body['plan'];
    if (planRaw is Map) {
      return RafidainInstallmentPlan.fromMap(
        planRaw.map((k, v) => MapEntry(k.toString(), v)),
      );
    }
    return plan;
  }

  /// يرفع لقطة كاملة للخطط كباك أب على السيرفر.
  Future<int> uploadBackup(
    PlansApiConfig config,
    List<RafidainInstallmentPlan> plans,
  ) async {
    _ensureConfigured(config);
    final response = await _http
        .put(
          config.resolve('/api/backup/plans'),
          headers: {
            ..._headers(config),
            'Content-Type': 'application/json; charset=utf-8',
          },
          body: jsonEncode({
            'plans': plans.map((plan) => plan.toMap()).toList(),
          }),
        )
        .timeout(const Duration(seconds: 45));

    final body = _decodeMap(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_errorMessage(body, fallback: 'فشل رفع النسخة الاحتياطية'));
    }
    final count = body['count'];
    if (count is num) {
      return count.toInt();
    }
    return plans.length;
  }

  Future<int> uploadAppStateBackup(
    PlansApiConfig config, {
    required List<RafidainInstallmentPlan> plans,
    required Map<String, dynamic> doctorSelection,
  }) async {
    _ensureConfigured(config);
    final response = await _http
        .put(
          config.resolve('/api/backup/app-state'),
          headers: {
            ..._headers(config),
            'Content-Type': 'application/json; charset=utf-8',
          },
          body: jsonEncode({
            'schemaVersion': 1,
            'plans': plans.map((plan) => plan.toMap()).toList(),
            'doctorSelection': doctorSelection,
          }),
        )
        .timeout(const Duration(seconds: 45));

    final body = _decodeMap(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_errorMessage(body, fallback: 'فشل رفع النسخة الاحتياطية الشاملة'));
    }
    final count = body['plansCount'];
    if (count is num) {
      return count.toInt();
    }
    return plans.length;
  }

  Future<Map<String, dynamic>> fetchAppStateBackup(PlansApiConfig config) async {
    _ensureConfigured(config);
    final response = await _http
        .get(
          config.resolve('/api/backup/app-state'),
          headers: _headers(config),
        )
        .timeout(const Duration(seconds: 20));

    final body = _decodeMap(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_errorMessage(body, fallback: 'فشل جلب النسخة الاحتياطية الشاملة'));
    }
    return body;
  }

  Future<void> ping(PlansApiConfig config) async {
    _ensureConfigured(config);
    final health = await _http
        .get(config.resolve('/health'))
        .timeout(const Duration(seconds: 12));
    if (health.statusCode < 200 || health.statusCode >= 300) {
      throw Exception('السيرفر لم يستجب بشكل صحيح (${health.statusCode})');
    }

    final plansResponse = await _http
        .get(
          config.resolve('/api/plans'),
          headers: _headers(config),
        )
        .timeout(const Duration(seconds: 12));
    if (plansResponse.statusCode == 401) {
      throw Exception('مفتاح API غير صحيح');
    }
    if (plansResponse.statusCode < 200 || plansResponse.statusCode >= 300) {
      throw Exception('فشل التحقق من API الخطط (${plansResponse.statusCode})');
    }
  }

  Map<String, String> _headers(PlansApiConfig config) {
    return {
      'Accept': 'application/json',
      'x-api-key': config.apiKey.trim(),
    };
  }

  void _ensureConfigured(PlansApiConfig config) {
    if (!config.isConfigured) {
      throw Exception(
        'أدخل عنوان سيرفر خطط الأقساط ومفتاح API من الإعدادات أولاً.',
      );
    }
  }

  Map<String, dynamic> _decodeMap(http.Response response) {
    if (response.body.trim().isEmpty) {
      return const {};
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return decoded.map((k, v) => MapEntry(k.toString(), v));
    }
    return const {};
  }

  String _errorMessage(Map<String, dynamic> body, {required String fallback}) {
    final error = body['error']?.toString().trim();
    if (error != null && error.isNotEmpty) {
      return error;
    }
    return fallback;
  }
}
