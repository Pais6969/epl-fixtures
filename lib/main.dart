import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'pages/home_page.dart';
import 'services/notification_service.dart';
import 'services/settings_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Data format tanggal bahasa Indonesia (Senin, 19 Oktober 2026, dst.)
  await initializeDateFormatting('id_ID');
  // [UAS] Memuat pengaturan tersimpan dan menyiapkan notifikasi.
  await AppSettings.instance.load();
  await NotificationService.init();
  runApp(const EplApp());
}

class EplApp extends StatelessWidget {
  const EplApp({super.key});

  @override
  Widget build(BuildContext context) {
    // [UAS] Dibangun ulang saat pengguna mengganti mode terang/gelap.
    return ListenableBuilder(
      listenable: AppSettings.instance,
      builder: (context, _) => MaterialApp(
        title: 'EPL Fixtures',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: AppSettings.instance.themeMode,
        home: const HomePage(),
      ),
    );
  }
}
