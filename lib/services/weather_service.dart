import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/weather_model.dart';

/// [UAS] Prakiraan cuaca dari Open-Meteo (gratis, tanpa API key).
/// Dokumentasi: https://open-meteo.com/en/docs
class WeatherService {
  WeatherService._();

  static final http.Client _client = http.Client();

  // Cache di memori selama 15 menit agar tidak meminta data yang sama.
  static final Map<String, (DateTime, WeatherForecast)> _memo = {};

  static Future<WeatherForecast> forecast(double lat, double lon) async {
    final key = '${lat.toStringAsFixed(2)},${lon.toStringAsFixed(2)}';
    final memo = _memo[key];
    if (memo != null &&
        DateTime.now().difference(memo.$1) < const Duration(minutes: 15)) {
      return memo.$2;
    }

    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': '$lat',
      'longitude': '$lon',
      'current': 'temperature_2m,weather_code',
      'hourly': 'temperature_2m,weather_code,precipitation_probability',
      'timezone': 'auto',
      'past_days': '1',
      'forecast_days': '16',
    });

    final response =
        await _client.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('Cuaca gagal dimuat (kode ${response.statusCode}).');
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final offset =
        Duration(seconds: (json['utc_offset_seconds'] as num?)?.toInt() ?? 0);

    // Waktu dari Open-Meteo berupa waktu lokal lokasi tanpa zona,
    // diubah ke UTC dengan mengurangi selisih zona waktunya.
    DateTime toUtc(String local) =>
        DateTime.parse('${local}Z').subtract(offset);

    final cur = json['current'] as Map<String, dynamic>;
    final current = WeatherPoint(
      timeUtc: toUtc(cur['time'] as String),
      code: (cur['weather_code'] as num).toInt(),
      temperature: (cur['temperature_2m'] as num).toDouble(),
    );

    final h = json['hourly'] as Map<String, dynamic>;
    final times = (h['time'] as List).cast<String>();
    final codes = h['weather_code'] as List;
    final temps = h['temperature_2m'] as List;
    final rains = h['precipitation_probability'] as List;
    final hourly = <WeatherPoint>[
      for (var i = 0; i < times.length; i++)
        if (codes[i] != null && temps[i] != null)
          WeatherPoint(
            timeUtc: toUtc(times[i]),
            code: (codes[i] as num).toInt(),
            temperature: (temps[i] as num).toDouble(),
            precipitationChance: (rains[i] as num?)?.toInt(),
          ),
    ];

    final result = WeatherForecast(
      current: current,
      hourly: hourly,
      utcOffset: offset,
      timezoneAbbreviation: json['timezone_abbreviation'] as String? ?? '',
    );
    _memo[key] = (DateTime.now(), result);
    return result;
  }
}
