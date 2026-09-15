import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hsabat/data/exporters/doctor_report_word_exporter.dart';
import 'package:hsabat/domain/entities/doctor_monthly_payment_row.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('doctor report word export creates editable docx', () async {
    final exporter = DoctorReportWordExporter();
    final out = await exporter.export(
      doctorName: 'د نغم جريو',
      periodLabel: 'شهر 8/2026',
      rows: [
        DoctorMonthlyPaymentRow(
          paymentId: '1',
          invoiceId: '1',
          patientName: 'سرور حيدر صاحب',
          phoneNumber: '07801425094',
          amount: 25000,
          paymentDate: DateTime(2026, 8, 6),
          paymentMethod: 'نقدي',
          treatmentDoctor: 'د نغم جريو',
          isRafidainInstallmentSource: false,
        ),
      ],
      totalAmount: 35305000,
      doctorPercent: 50,
      doctorAmount: 17652500,
      appliedTarakeebAmount: 2500500,
      appliedTamweelAmount: 983250,
      finalDoctorAmount: 14168750,
      revealInExplorer: false,
    );

    final file = File(out.filePath);
    expect(await file.exists(), isTrue);
    expect(p.extension(out.filePath), '.docx');
    expect(await file.length(), greaterThan(1000));
  });
}
