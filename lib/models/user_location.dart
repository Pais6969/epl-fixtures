/// Lokasi pengguna dari GPS yang disimpan di perangkat.
class UserLocation {
  const UserLocation({
    required this.latitude,
    required this.longitude,
    required this.label,
    required this.savedAt,
  });

  final double latitude;
  final double longitude;

  /// Nama tempat hasil reverse geocoding, misalnya "Malang, Jawa Timur".
  final String label;
  final DateTime savedAt;

  /// Nama kota saja (bagian pertama label).
  String get city => label.split(',').first.trim();

  Map<String, dynamic> toJson() => {
        'lat': latitude,
        'lon': longitude,
        'label': label,
        'savedAt': savedAt.toIso8601String(),
      };

  factory UserLocation.fromJson(Map<String, dynamic> json) => UserLocation(
        latitude: (json['lat'] as num).toDouble(),
        longitude: (json['lon'] as num).toDouble(),
        label: json['label'] as String? ?? 'Lokasiku',
        savedAt: DateTime.tryParse(json['savedAt'] as String? ?? '') ??
            DateTime.now(),
      );
}
