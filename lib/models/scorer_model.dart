import 'team_model.dart';

/// Satu baris daftar pencetak gol dari /competitions/PL/scorers.
class ScorerModel {
  const ScorerModel({
    required this.playerName,
    required this.team,
    required this.goals,
    this.assists,
    this.penalties,
    this.nationality,
  });

  final String playerName;
  final TeamModel team;
  final int goals;
  final int? assists;
  final int? penalties;
  final String? nationality;

  factory ScorerModel.fromJson(Map<String, dynamic> json) {
    final player =
        json['player'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    return ScorerModel(
      playerName: player['name'] as String? ?? '-',
      nationality: player['nationality'] as String?,
      team: TeamModel.fromJson(
        json['team'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      ),
      goals: (json['goals'] as num?)?.toInt() ?? 0,
      assists: (json['assists'] as num?)?.toInt(),
      penalties: (json['penalties'] as num?)?.toInt(),
    );
  }
}
