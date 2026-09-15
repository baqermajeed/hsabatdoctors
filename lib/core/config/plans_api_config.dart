class PlansApiConfig {
  const PlansApiConfig({
    required this.baseUrl,
    required this.apiKey,
  });

  static const managed = PlansApiConfig(
    baseUrl: 'https://hsabat.farahdent.com',
    apiKey: '533dbf61ca7bdd5532aaebc03e1ea2e9136b9bb4c7f3320c910ddd0d3715375a',
  );

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
