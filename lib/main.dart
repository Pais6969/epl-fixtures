import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'pages/home_page.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Data format tanggal bahasa Indonesia (Senin, 19 Oktober 2026, dst.)
  await initializeDateFormatting('id_ID');
  runApp(const EplApp());
}

class EplApp extends StatelessWidget {
  const EplApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EPL Fixtures',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const HomePage(),
    );
  }
}
