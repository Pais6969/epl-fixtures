import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Satu data yang tersimpan di cache beserta waktu penyimpanannya.
class CacheEntry {
  const CacheEntry({required this.body, required this.savedAt});

  final String body;
  final DateTime savedAt;

  Duration get age => DateTime.now().difference(savedAt);
}

/// Cache sederhana berbasis SharedPreferences.
///
/// Respons API disimpan apa adanya (teks JSON) dengan kunci `cache:<path>`,
/// sehingga data tetap bisa ditampilkan saat tidak ada internet dan
/// permintaan ke API lebih hemat (batas paket gratis 10 request/menit).
class CacheStore {
  CacheStore._();

  static const _prefix = 'cache:';

  static Future<CacheEntry?> read(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_prefix$key');
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return CacheEntry(
        body: map['body'] as String,
        savedAt: DateTime.parse(map['savedAt'] as String),
      );
    } catch (_) {
      return null; // data cache rusak, abaikan
    }
  }

  static Future<void> write(String key, String body) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_prefix$key',
      jsonEncode({'body': body, 'savedAt': DateTime.now().toIso8601String()}),
    );
  }

  /// Jumlah data yang tersimpan di cache.
  static Future<int> count() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getKeys().where((k) => k.startsWith(_prefix)).length;
  }

  /// Menghapus seluruh cache (pengaturan pengguna tidak ikut terhapus).
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_prefix)).toList();
    for (final k in keys) {
      await prefs.remove(k);
    }
  }
}
