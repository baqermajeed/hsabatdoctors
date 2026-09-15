enum SqlAuthMode {
  windows,
  sqlServer,
}

class DatabaseConfig {
  const DatabaseConfig({
    required this.server,
    required this.database,
    required this.port,
    required this.driver,
    required this.authMode,
    required this.encrypt,
    required this.trustServerCertificate,
    this.username,
    this.password,
  });

  final String server;
  final String database;
  final int port;
  final String driver;
  final SqlAuthMode authMode;
  final bool encrypt;
  final bool trustServerCertificate;
  final String? username;
  final String? password;

  factory DatabaseConfig.devDefaults() {
    return const DatabaseConfig(
      server: 'localhost',
      database: 'XanthusClinicsData',
      port: 1433,
      driver: 'ODBC Driver 17 for SQL Server',
      authMode: SqlAuthMode.windows,
      encrypt: false,
      trustServerCertificate: true,
    );
  }

  DatabaseConfig copyWith({
    String? server,
    String? database,
    int? port,
    String? driver,
    SqlAuthMode? authMode,
    bool? encrypt,
    bool? trustServerCertificate,
    String? username,
    String? password,
  }) {
    return DatabaseConfig(
      server: server ?? this.server,
      database: database ?? this.database,
      port: port ?? this.port,
      driver: driver ?? this.driver,
      authMode: authMode ?? this.authMode,
      encrypt: encrypt ?? this.encrypt,
      trustServerCertificate:
          trustServerCertificate ?? this.trustServerCertificate,
      username: username ?? this.username,
      password: password ?? this.password,
    );
  }

  String buildConnectionString() {
    final base =
        'DRIVER={$driver};SERVER=$server,$port;DATABASE=$database;'
        'Encrypt=${encrypt ? "yes" : "no"};'
        'TrustServerCertificate=${trustServerCertificate ? "yes" : "no"};';

    if (authMode == SqlAuthMode.windows) {
      return '$base Trusted_Connection=yes;';
    }

    final user = username?.trim() ?? '';
    final pass = password?.trim() ?? '';
    if (user.isEmpty || pass.isEmpty) {
      throw Exception(
        'يجب إدخال اسم المستخدم وكلمة المرور عند استخدام SQL Server Authentication.',
      );
    }

    return '$base UID=$user;PWD=$pass;';
  }
}
