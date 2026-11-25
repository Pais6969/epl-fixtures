import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_location.dart';

class LocationException implements Exception {
  const LocationException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Koordinat sederhana (lintang, bujur).
class LatLon {
  const LatLon(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}

/// [UAS] Mengambil lokasi GPS pengguna dan mengubah alamat <-> koordinat.
class LocationService {
  LocationService._();

  static final Geocoding _geocoding = Geocoding(locale: const Locale('id', 'ID'));

  /// Mengambil lokasi pengguna saat ini, lengkap dengan nama tempatnya.
  /// Meminta izin lokasi bila belum diberikan.
  static Future<UserLocation> getCurrentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationException(
        'Layanan lokasi (GPS) di perangkat sedang mati. '
        'Aktifkan lokasi lalu coba lagi.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const LocationException('Izin lokasi ditolak.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationException(
        'Izin lokasi ditolak permanen. Buka Pengaturan > Aplikasi > '
        'EPL Fixtures > Izin untuk mengaktifkannya.',
      );
    }

    Position? pos;
    try {
      pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 20),
        ),
      );
    } catch (e) {
      // GPS belum mendapat sinyal baru (timeout, sering terjadi di dalam
      // ruangan atau di emulator) atau error lain dari layanan lokasi:
      // pakai lokasi terakhir yang diketahui perangkat.
      debugPrint('getCurrentPosition gagal: $e');
      pos = await Geolocator.getLastKnownPosition();
    }
    if (pos == null) {
      throw const LocationException(
        'Lokasi belum didapat dalam 20 detik. Coba di tempat terbuka, '
        'atau di emulator kirim lokasi lewat Extended Controls > Location '
        '> Set Location.',
      );
    }

    final label = await _placeName(pos.latitude, pos.longitude);
    return UserLocation(
      latitude: pos.latitude,
      longitude: pos.longitude,
      label: label,
      savedAt: DateTime.now(),
    );
  }

  /// Reverse geocoding: koordinat -> "Kota, Provinsi, Negara".
  static Future<String> _placeName(double lat, double lon) async {
    try {
      final marks = await _geocoding.placemarkFromCoordinates(lat, lon);
      if (marks.isNotEmpty) {
        final p = marks.first;
        final city = [p.locality, p.subAdministrativeArea]
            .firstWhere((s) => s != null && s.isNotEmpty, orElse: () => null);
        final parts = <String>[
          if (city != null) city,
          if (p.administrativeArea?.isNotEmpty ?? false) p.administrativeArea!,
          if (p.country?.isNotEmpty ?? false) p.country!,
        ];
        if (parts.isNotEmpty) return parts.join(', ');
      }
    } catch (_) {
      // Geocoder perangkat tidak tersedia / offline: pakai koordinat.
    }
    return '${lat.toStringAsFixed(3)}, ${lon.toStringAsFixed(3)}';
  }

  /// Geocoding: alamat -> koordinat. Hasil disimpan agar tidak diulang.
  static Future<LatLon?> coordinatesOf(String address) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'geo:$address';
    final saved = prefs.getString(key);
    if (saved != null) {
      final m = jsonDecode(saved) as Map<String, dynamic>;
      return LatLon((m['lat'] as num).toDouble(), (m['lon'] as num).toDouble());
    }
    try {
      final results = await _geocoding.locationFromAddress(address);
      if (results.isEmpty) return null;
      final r = results.first;
      await prefs.setString(
        key,
        jsonEncode({'lat': r.latitude, 'lon': r.longitude}),
      );
      return LatLon(r.latitude, r.longitude);
    } catch (_) {
      return null;
    }
  }

  /// Mencoba beberapa alamat sampai salah satu ditemukan.
  static Future<LatLon?> coordinatesOfAny(List<String> candidates) async {
    for (final c in candidates) {
      final r = await coordinatesOf(c);
      if (r != null) return r;
    }
    return null;
  }

  /// Jarak dua titik dalam kilometer.
  static double distanceKm(LatLon a, LatLon b) =>
      Geolocator.distanceBetween(
        a.latitude,
        a.longitude,
        b.latitude,
        b.longitude,
      ) /
      1000;
}
