import '../../core/database/xanthus_readonly_client.dart';
import '../models/payment_transaction.dart';

class PaymentRepository {
  PaymentRepository(this._client);

  final XanthusReadonlyClient _client;

  Future<List<PaymentTransaction>> fetchPaymentSample({int limit = 20}) async {
    final safeLimit = limit < 1 ? 1 : limit;
    final rows = await _client.query('''
SELECT TOP ($safeLimit)
  [ID],
  [nom],
  [paname],
  [monyyy],
  [typ],
  [banknom],
  [date1]
FROM [CBT_B130_011]
ORDER BY [date1] DESC, [ID] DESC
''');

    return rows.map(PaymentTransaction.fromMap).toList();
  }
}
