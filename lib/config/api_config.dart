/// Konfigurasi API football-data.org.
///
/// Token TIDAK ditulis di kode supaya aman saat repository dibuat public.
/// Token diberikan saat menjalankan aplikasi:
///   flutter run --dart-define=FOOTBALL_DATA_TOKEN=tokenmu
class ApiConfig {
  ApiConfig._();

  static const String baseUrl = 'https://api.football-data.org/v4';

  /// Kode kompetisi Premier League di football-data.org.
  static const String competition = 'PL';

  static const String token = String.fromEnvironment('FOOTBALL_DATA_TOKEN');

  static bool get hasToken => token.isNotEmpty;
}
