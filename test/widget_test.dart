import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hsabat/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('shows home doctors title', (WidgetTester tester) async {
    await tester.pumpWidget(const DoctorAccountingApp());
    await tester.pump();
    expect(find.text('لوحة الأطباء'), findsOneWidget);
    // Flush delayed entrance animations without waiting forever on repeating loops.
    await tester.pump(const Duration(milliseconds: 600));
  });
}
