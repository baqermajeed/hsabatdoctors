class PlansApiConfig {
  const PlansApiConfig({
    required this.baseUrl,
    required this.apiKey,
  });

  final String baseUrl;
  final String apiKey;

  bool get isConfigured {
    final url = baseUrl.trim();
    final key = apiKey.trim();
    return url.isNotEmpty && key.isNotEmpty;
  }

  Uri resolve(String path, [Map<String, String>? query]) {
    final normalizedBase = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$normalizedBase$normalizedPath').replace(queryParameters: query);
  }
}
