class TeamModel {
  const TeamModel({
    required this.id,
    required this.name,
    required this.shortName,
    required this.tla,
    required this.crest,
  });

  final int id;
  final String name;
  final String shortName;
  final String tla;
  final String crest;

  factory TeamModel.fromJson(Map<String, dynamic> json) {
    final name = json['name'] as String? ?? 'Belum ditentukan';
    return TeamModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: name,
      shortName: json['shortName'] as String? ?? name,
      tla: json['tla'] as String? ?? '-',
      crest: json['crest'] as String? ?? '',
    );
  }
}
