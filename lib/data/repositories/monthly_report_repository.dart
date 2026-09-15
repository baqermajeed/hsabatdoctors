import 'package:intl/intl.dart' show DateFormat;

import '../../core/database/xanthus_readonly_client.dart';
import '../models/xanthus_payment_row.dart';

class MonthlyReportRepository {
  MonthlyReportRepository(this._client);

  final XanthusReadonlyClient _client;
  final DateFormat _sqlDateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
  String? _cachedPhoneColumn;

  Future<List<XanthusPaymentRow>> fetchPaymentsInMonth({
    required int year,
    required int month,
    String? doctorName,
  }) async {
    final from = DateTime(year, month, 1);
    final to = DateTime(year, month + 1, 1);
    return fetchPaymentsInRange(
      from: from,
      toExclusive: to,
      doctorName: doctorName,
    );
  }

  Future<List<XanthusPaymentRow>> fetchPaymentsInRange({
    required DateTime from,
    required DateTime toExclusive,
    String? doctorName,
  }) async {
    final phoneColumn = await _getPhoneColumnCached();
    final phoneSelect = phoneColumn == null
        ? "N'' AS [phone]"
        : "ISNULL(CONVERT(NVARCHAR(100), pa.$phoneColumn), N'') AS [phone]";

    final doctorFilter = (doctorName == null || doctorName.trim().isEmpty)
        ? ''
        : "  AND LTRIM(RTRIM(ISNULL(td.[doctor], N''))) = N'${_escapeSqlString(doctorName.trim())}'\n";

    final sql = '''
SELECT
  p.[ID],
  p.[nom],
  p.[paname],
  p.[monyyy],
  p.[typ],
  p.[banknom],
  p.[date1],
  $phoneSelect,
  ISNULL(td.[doctor], N'') AS [treatmentDoctor]
FROM [CBT_B130_011] p
LEFT JOIN [CBT_B120_043] inv
  ON inv.[ID] = CASE
      WHEN p.[nom] NOT LIKE '%[^0-9]%' AND LTRIM(RTRIM(p.[nom])) <> N''
        THEN CONVERT(INT, p.[nom])
      ELSE NULL
    END
OUTER APPLY (
  SELECT TOP (1)
    LTRIM(RTRIM(d.[doctor])) AS [doctor]
  FROM [CBT_B120_045] d
  WHERE d.[visit id] = inv.[ID]
    AND LTRIM(RTRIM(ISNULL(d.[doctor], N''))) <> N''
  ORDER BY d.[ID] DESC
) td
LEFT JOIN [CBT_A150_028] pa
  ON pa.[ID] = CASE
      WHEN inv.[pafile] NOT LIKE '%[^0-9]%' AND LTRIM(RTRIM(inv.[pafile])) <> N''
        THEN CONVERT(INT, inv.[pafile])
      ELSE NULL
    END
WHERE p.[date1] >= '${_sqlDateFormat.format(from)}'
  AND p.[date1] < '${_sqlDateFormat.format(toExclusive)}'
$doctorFilter
ORDER BY p.[date1] ASC, p.[ID] ASC
''';

    final rows = await _client.query(sql);
    return rows.map(XanthusPaymentRow.fromMap).toList();
  }

  Future<String?> _getPhoneColumnCached() async {
    if (_cachedPhoneColumn != null) {
      return _cachedPhoneColumn;
    }
    _cachedPhoneColumn = await _detectPhoneColumn();
    return _cachedPhoneColumn;
  }

  Future<List<String>> fetchDistinctTreatmentDoctors() async {
    const sql = '''
SELECT DISTINCT
  LTRIM(RTRIM([doctor])) AS [doctor]
FROM [CBT_B120_045]
WHERE LTRIM(RTRIM(ISNULL([doctor], N''))) <> N''
ORDER BY LTRIM(RTRIM([doctor])) ASC
''';
    final rows = await _client.query(sql);
    return rows
        .map((row) {
          final value = row.entries
              .firstWhere(
                (entry) => entry.key.toLowerCase() == 'doctor',
                orElse: () => const MapEntry('doctor', null),
              )
              .value;
          return value?.toString().trim() ?? '';
        })
        .where((name) => name.isNotEmpty)
        .toList();
  }

  Future<String?> _detectPhoneColumn() async {
    const sql = '''
SELECT [COLUMN_NAME]
FROM [INFORMATION_SCHEMA].[COLUMNS]
WHERE [TABLE_NAME] = 'CBT_A150_028'
ORDER BY [ORDINAL_POSITION] ASC
''';
    final rows = await _client.query(sql);
    final columns = rows
        .map((row) {
          final value = row.entries
              .firstWhere(
                (entry) => entry.key.toLowerCase() == 'column_name',
                orElse: () => const MapEntry('COLUMN_NAME', null),
              )
              .value;
          return value?.toString().trim() ?? '';
        })
        .where((name) => name.isNotEmpty)
        .toList();

    if (columns.isEmpty) {
      return null;
    }

    const preferredExact = <String>[
      'phone',
      'phone1',
      'phone2',
      'mobile',
      'mobileno',
      'phoneno',
      'tel',
    ];

    for (final candidate in preferredExact) {
      final match = columns.where((name) => name.toLowerCase() == candidate).toList();
      if (match.isNotEmpty) {
        return _toBracketedIdentifier(match.first);
      }
    }

    final fallback = columns.where((name) {
      final key = name.toLowerCase();
      return key.contains('phone') || key.contains('mobile') || key.contains('tel');
    }).toList();

    if (fallback.isNotEmpty) {
      return _toBracketedIdentifier(fallback.first);
    }

    return null;
  }

  String _toBracketedIdentifier(String value) {
    final escaped = value.replaceAll(']', ']]');
    return '[$escaped]';
  }

  String _escapeSqlString(String value) {
    return value.replaceAll("'", "''");
  }
}
