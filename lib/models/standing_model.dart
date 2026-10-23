import 'team_model.dart';

class StandingRow {
  const StandingRow({
    required this.position,
    required this.team,
    required this.playedGames,
    required this.won,
    required this.draw,
    required this.lost,
    required this.goalsFor,
    required this.goalsAgainst,
    required this.goalDifference,
    required this.points,
  });

  final int position;
  final TeamModel team;
  final int playedGames;
  final int won;
  final int draw;
  final int lost;
  final int goalsFor;
  final int goalsAgainst;
  final int goalDifference;
  final int points;

  factory StandingRow.fromJson(Map<String, dynamic> json) {
    int n(String key) => (json[key] as num?)?.toInt() ?? 0;

    return StandingRow(
      position: n('position'),
      team: TeamModel.fromJson(
        json['team'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      ),
      playedGames: n('playedGames'),
      won: n('won'),
      draw: n('draw'),
      lost: n('lost'),
      goalsFor: n('goalsFor'),
      goalsAgainst: n('goalsAgainst'),
      goalDifference: n('goalDifference'),
      points: n('points'),
    );
  }
}
