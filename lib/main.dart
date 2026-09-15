import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/theme/app_theme.dart';
import 'presentation/screens/app_shell_screen.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = true;
  runApp(const DoctorAccountingApp());
}

class DoctorAccountingApp extends StatelessWidget {
  const DoctorAccountingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dental Pro — تقارير الأطباء',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      locale: const Locale('ar'),
      supportedLocales: const [
        Locale('ar'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const AppShellScreen(),
    );
  }
}
