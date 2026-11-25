import 'team_model.dart';

/// Orang dalam klub: pemain skuad atau pelatih.
class PersonModel {
  const PersonModel({
    required this.id,
    required this.name,
    this.position,
    this.nationality,
    this.dateOfBirth,
    this.shirtNumber,
  });

  final int id;
  final String name;
  final String? position;
  final String? nationality;
  final DateTime? dateOfBirth;
  final int? shirtNumber;

  /// Umur dalam tahun (null bila tanggal lahir tidak ada).
  int? get age {
    final dob = dateOfBirth;
    if (dob == null) return null;
    final now = DateTime.now();
    var years = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      years--;
    }
    return years;
  }

  /// Posisi dalam bahasa Indonesia.
  String get positionLabel => switch (position) {
        'Goalkeeper' => 'Penjaga gawang',
        'Defence' || 'Defender' => 'Bek',
        'Midfield' || 'Midfielder' => 'Gelandang',
        'Offence' || 'Attacker' || 'Forward' => 'Penyerang',
        null || '' => 'Lainnya',
        _ => position!,
      };

  factory PersonModel.fromJson(Map<String, dynamic> json) {
    final dob = json['dateOfBirth'] as String?;
    return PersonModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '-',
      position: json['position'] as String?,
      nationality: json['nationality'] as String?,
      dateOfBirth: dob == null ? null : DateTime.tryParse(dob),
      shirtNumber: (json['shirtNumber'] as num?)?.toInt(),
    );
  }
}

/// Detail satu klub dari endpoint /teams/{id}.
class TeamDetail {
  const TeamDetail({
    required this.team,
    this.venue,
    this.address,
    this.website,
    this.clubColors,
    this.founded,
    this.coach,
    this.squad = const [],
  });

  final TeamModel team;
  final String? venue;
  final String? address;
  final String? website;
  final String? clubColors;
  final int? founded;
  final PersonModel? coach;

  /// Pada paket gratis API, skuad bisa kosong.
  final List<PersonModel> squad;

  /// Kandidat teks untuk mencari koordinat stadion, dari yang paling
  /// spesifik. Dicoba berurutan sampai ada yang ditemukan geocoder.
  List<String> get geocodeCandidates {
    final v = venue?.trim() ?? '';
    final a = address?.trim() ?? '';
    return [
      if (v.isNotEmpty && a.isNotEmpty) '$v, $a, United Kingdom',
      if (a.isNotEmpty) '$a, United Kingdom',
      if (v.isNotEmpty) '$v, United Kingdom',
    ];
  }

  factory TeamDetail.fromJson(Map<String, dynamic> json) {
    final coachJson = json['coach'] as Map<String, dynamic>?;
    final squad = (json['squad'] as List<dynamic>? ?? const <dynamic>[])
        .map((e) => PersonModel.fromJson(e as Map<String, dynamic>))
        .toList();
    return TeamDetail(
      team: TeamModel.fromJson(json),
      venue: json['venue'] as String?,
      address: json['address'] as String?,
      website: json['website'] as String?,
      clubColors: json['clubColors'] as String?,
      founded: (json['founded'] as num?)?.toInt(),
      coach: coachJson == null || coachJson['name'] == null
          ? null
          : PersonModel.fromJson(coachJson),
      squad: squad,
    );
  }
}
