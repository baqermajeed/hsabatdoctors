import 'package:easy_mssql_windows/easy_mssql_windows.dart';

import '../config/database_config.dart';

class XanthusReadonlyClient {
  final OdbcConnector _connector = OdbcConnector();
  bool _isConnected = false;

  bool get isConnected => _isConnected;

  Future<String> connect(DatabaseConfig config) async {
    final message = await _connector.connect(config.buildConnectionString());
    _isConnected = true;
    return message;
  }

  void disconnect() {
    _connector.disconnect();
    _isConnected = false;
  }

  Future<List<Map<String, dynamic>>> query(String sql) async {
    _enforceReadOnlySql(sql);
    return _connector.executeQuery(sql);
  }

  void _enforceReadOnlySql(String sql) {
    final normalized = sql.trim().toLowerCase();
    final readOnlyStart = normalized.startsWith('select');
    if (!readOnlyStart) {
      throw Exception('يسمح فقط بأوامر SELECT على قاعدة Xanthus.');
    }

    const forbidden = <String>[
      ' insert ',
      ' update ',
      ' delete ',
      ' alter ',
      ' drop ',
      ' truncate ',
      ' merge ',
      ' create ',
      ' execute ',
      ' exec ',
    ];

    final padded = ' $normalized ';
    for (final token in forbidden) {
      if (padded.contains(token)) {
        throw Exception('تم حظر أمر غير آمن داخل الاستعلام: ${token.trim()}');
      }
    }
  }
}
