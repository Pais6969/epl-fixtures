import 'package:flutter/material.dart';

import '../models/standing_model.dart';
import '../models/team_model.dart';
import '../services/football_api_service.dart';
import '../services/notification_service.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import '../widgets/state_views.dart';
import '../widgets/team_crest.dart';
import 'club_page.dart';

/// [UAS] Pencarian klub. Daftar klub diambil dari data klasemen
/// (sudah tersimpan di cache, jadi tidak menambah request ke API).
///
/// Bila [pickMode] true, halaman dipakai untuk memilih klub favorit
/// dan mengembalikan [TeamModel] yang dipilih.
class SearchPage extends StatefulWidget {
  const SearchPage({super.key, this.pickMode = false});

  final bool pickMode;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  late Future<List<StandingRow>> _future;
  final _controller = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = FootballApiService.shared.fetchStandings();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _matches(TeamModel t) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return t.name.toLowerCase().contains(q) ||
        t.shortName.toLowerCase().contains(q) ||
        t.tla.toLowerCase().contains(q);
  }

  Future<void> _toggleFavorite(TeamModel team) async {
    final s = AppSettings.instance;
    await s.setFavoriteTeam(s.favoriteTeamId == team.id ? null : team);
    ReminderService.resync().ignore();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pickMode ? 'Pilih klub favorit' : 'Cari klub'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _controller,
              autofocus: !widget.pickMode,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Ketik nama klub, mis. Arsenal atau MUN',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _controller.clear();
                          setState(() => _query = '');
                        },
                      ),
                filled: true,
                fillColor: p.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: p.line),
                ),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<StandingRow>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const LoadingView(message: 'Memuat daftar klub...');
                }
                if (snap.hasError) {
                  final e = snap.error;
                  return ErrorView(
                    message: e is ApiException
                        ? e.message
                        : 'Terjadi kesalahan yang tidak terduga.',
                    onRetry: () => setState(() {
                      _future =
                          FootballApiService.shared.fetchStandings(force: true);
                    }),
                  );
                }
                final teams = snap.data!
                    .map((r) => r.team)
                    .where(_matches)
                    .toList()
                  ..sort((a, b) => a.shortName.compareTo(b.shortName));
                if (teams.isEmpty) {
                  return EmptyView(
                    icon: Icons.search_off,
                    message: 'Tidak ada klub yang cocok dengan "$_query".',
                  );
                }
                return ListenableBuilder(
                  listenable: AppSettings.instance,
                  builder: (context, _) {
                    final favId = AppSettings.instance.favoriteTeamId;
                    return ListView.builder(
                      itemCount: teams.length,
                      itemBuilder: (context, i) {
                        final t = teams[i];
                        final isFav = t.id == favId;
                        return ListTile(
                          leading: TeamCrest(url: t.crest, size: 32),
                          title: Text(
                            t.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(t.tla),
                          trailing: IconButton(
                            tooltip: isFav ? 'Hapus favorit' : 'Jadikan favorit',
                            icon: Icon(
                              isFav ? Icons.star : Icons.star_border,
                              color: isFav ? AppColors.amber : p.muted,
                            ),
                            onPressed: () => _toggleFavorite(t),
                          ),
                          onTap: () {
                            if (widget.pickMode) {
                              Navigator.of(context).pop(t);
                            } else {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ClubPage(team: t),
                                ),
                              );
                            }
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
