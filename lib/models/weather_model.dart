import 'package:flutter/material.dart';

/// Kondisi cuaca pada satu waktu (dari Open-Meteo).
class WeatherPoint {
  const WeatherPoint({
    required this.timeUtc,
    required this.code,
    required this.temperature,
    this.precipitationChance,
  });

  final DateTime timeUtc;

  /// Kode cuaca WMO (0 = cerah, 61 = hujan ringan, dst.).
  final int code;
  final double temperature;

  /// Peluang hujan dalam persen (khusus prakiraan per jam).
  final int? precipitationChance;

  WeatherKind get kind => WeatherKind.fromCode(code);
}

/// Hasil prakiraan cuaca untuk satu lokasi.
class WeatherForecast {
  const WeatherForecast({
    required this.current,
    required this.hourly,
    required this.utcOffset,
    required this.timezoneAbbreviation,
  });

  final WeatherPoint current;
  final List<WeatherPoint> hourly;

  /// Selisih waktu lokasi tersebut terhadap UTC.
  final Duration utcOffset;
  final String timezoneAbbreviation;

  /// Waktu lokal di lokasi tersebut untuk [utc].
  DateTime localTimeAt(DateTime utc) => utc.toUtc().add(utcOffset);

  /// Prakiraan per jam yang paling dekat dengan [utc]. Null bila di luar
  /// rentang prakiraan (lebih dari ~16 hari ke depan atau sudah lewat jauh).
  WeatherPoint? at(DateTime utc) {
    final target = utc.toUtc();
    WeatherPoint? best;
    var bestDiff = const Duration(hours: 2);
    for (final h in hourly) {
      final diff = h.timeUtc.difference(target).abs();
      if (diff < bestDiff) {
        best = h;
        bestDiff = diff;
      }
    }
    return best;
  }
}

/// Pengelompokan kode cuaca WMO menjadi kategori yang mudah dipahami.
enum WeatherKind {
  clear('Cerah', Icons.wb_sunny_outlined, Color(0xFFF2A900)),
  partlyCloudy('Cerah berawan', Icons.wb_cloudy_outlined, Color(0xFF8AA4B8)),
  cloudy('Mendung', Icons.cloud_outlined, Color(0xFF7D8A93)),
  fog('Berkabut', Icons.foggy, Color(0xFF9AA5AD)),
  drizzle('Gerimis', Icons.grain, Color(0xFF4A90C2)),
  rain('Hujan', Icons.umbrella_outlined, Color(0xFF2F6FB0)),
  heavyRain('Hujan lebat', Icons.water_drop_outlined, Color(0xFF1F4E8C)),
  snow('Salju', Icons.ac_unit, Color(0xFF6FA8DC)),
  storm('Badai petir', Icons.thunderstorm_outlined, Color(0xFF5B3F99)),
  unknown('Tidak diketahui', Icons.help_outline, Color(0xFF888888));

  const WeatherKind(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;

  bool get isWet =>
      this == drizzle || this == rain || this == heavyRain || this == storm;

  static WeatherKind fromCode(int code) {
    if (code == 0) return clear;
    if (code == 1 || code == 2) return partlyCloudy;
    if (code == 3) return cloudy;
    if (code == 45 || code == 48) return fog;
    if (code >= 51 && code <= 57) return drizzle;
    if (code == 61 || code == 63 || code == 66 || code == 80 || code == 81) {
      return rain;
    }
    if (code == 65 || code == 67 || code == 82) return heavyRain;
    if ((code >= 71 && code <= 77) || code == 85 || code == 86) return snow;
    if (code >= 95 && code <= 99) return storm;
    return unknown;
  }
}
