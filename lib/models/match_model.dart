import 'team_model.dart';

class ScoreModel {
  const ScoreModel({
    this.winner,
    this.homeFullTime,
    this.awayFullTime,
    this.homeHalfTime,
    this.awayHalfTime,
  });

  final String? winner;
  final int? homeFullTime;
  final int? awayFullTime;
  final int? homeHalfTime;
  final int? awayHalfTime;

  bool get hasFullTime => homeFullTime != null && awayFullTime != null;
  bool get hasHalfTime => homeHalfTime != null && awayHalfTime != null;

  factory ScoreModel.fromJson(Map<String, dynamic> json) {
    final full = json['fullTime'] as Map<String, dynamic>? ??
        const <String, dynamic>{};
    final half = json['halfTime'] as Map<String, dynamic>? ??
        const <String, dynamic>{};
    return ScoreModel(
      winner: json['winner'] as String?,
      homeFullTime: (full['home'] as num?)?.toInt(),
      awayFullTime: (full['away'] as num?)?.toInt(),
      homeHalfTime: (half['home'] as num?)?.toInt(),
      awayHalfTime: (half['away'] as num?)?.toInt(),
    );
  }
}

class MatchModel {
  const MatchModel({
    required this.id,
    required this.kickoff,
    required this.status,
    required this.matchday,
    required this.homeTeam,
    required this.awayTeam,
    required this.score,
    required this.referees,
  });

  final int id;

  /// Waktu kick-off dalam zona waktu perangkat (API memberi waktu UTC).
  final DateTime kickoff;
  final String status;
  final int matchday;
  final TeamModel homeTeam;
  final TeamModel awayTeam;
  final ScoreModel score;
  final List<String> referees;

  bool get isLive => status == 'IN_PLAY' || status == 'PAUSED';
  bool get isFinished => status == 'FINISHED' || status == 'AWARDED';
  bool get isUpcoming =>
      status == 'SCHEDULED' || status == 'TIMED' || status == 'POSTPONED';

  String get statusLabel {
    return switch (status) {
      'SCHEDULED' || 'TIMED' => 'Terjadwal',
      'IN_PLAY' => 'Berlangsung',
      'PAUSED' => 'Turun minum',
      'FINISHED' || 'AWARDED' => 'Selesai',
      'POSTPONED' => 'Ditunda',
      'SUSPENDED' => 'Dihentikan',
      'CANCELLED' => 'Dibatalkan',
      _ => status,
    };
  }

  factory MatchModel.fromJson(Map<String, dynamic> json) {
    final referees = (json['referees'] as List<dynamic>? ?? const <dynamic>[])
        .map((r) => (r as Map<String, dynamic>)['name'] as String?)
        .whereType<String>()
        .toList();

    return MatchModel(
      id: (json['id'] as num).toInt(),
      kickoff: DateTime.parse(json['utcDate'] as String).toLocal(),
      status: json['status'] as String? ?? 'UNKNOWN',
      matchday: (json['matchday'] as num?)?.toInt() ?? 0,
      homeTeam: TeamModel.fromJson(
        json['homeTeam'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      ),
      awayTeam: TeamModel.fromJson(
        json['awayTeam'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      ),
      score: ScoreModel.fromJson(
        json['score'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      ),
      referees: referees,
    );
  }
}

/// Hasil pengambilan jadwal satu musim, sudah diurutkan berdasarkan waktu.
class FixturesData {
  const FixturesData({required this.matches, required this.currentMatchday});

  final List<MatchModel> matches;
  final int currentMatchday;

  List<int> get matchdays {
    final days = matches.map((m) => m.matchday).where((d) => d > 0).toSet();
    return days.toList()..sort();
  }

  List<MatchModel> byMatchday(int matchday) =>
      matches.where((m) => m.matchday == matchday).toList();
}
