import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/match_model.dart';
import '../services/football_api_service.dart';
import '../services/notification_service.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import '../widgets/choice_pill.dart';
import '../widgets/common.dart';
import '../widgets/match_card.dart';
import '../widgets/state_views.dart';
import 'match_detail_page.dart';
import 'search_page.dart';

enum MatchFilter { all, favorite, upcoming, live, finished }

extension MatchFilterX on MatchFilter {
  String get label => switch (this) {
        MatchFilter.all => 'Semua',
        MatchFilter.favorite => 'Klub favorit',
        MatchFilter.upcoming => 'Akan main',
        MatchFilter.live => 'Berlangsung',
        MatchFilter.finished => 'Selesai',
      };

  bool accepts(MatchModel m, int? favoriteId) => switch (this) {
        MatchFilter.all => true,
        MatchFilter.favorite =>
          m.homeTeam.id == favoriteId || m.awayTeam.id == favoriteId,
        MatchFilter.upcoming => m.isUpcoming,
        MatchFilter.live => m.isLive,
        MatchFilter.finished => m.isFinished,
      };
}

class FixturesPage extends StatefulWidget {
  const FixturesPage({super.key, required this.service});

  final FootballApiService service;

  @override
  State<FixturesPage> createState() => _FixturesPageState();
}

class _FixturesPageState extends State<FixturesPage> {
  late Future<FixturesData> _future;
  int? _matchday; // null = ikut matchday saat ini dari API
  MatchFilter _filter = MatchFilter.all;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  /// [UAS] Setelah jadwal dimuat, pengingat klub favorit disinkronkan.
  Future<FixturesData> _load({bool force = false}) async {
    final data = await widget.service.fetchFixtures(force: force);
    ReminderService.syncFavorite(data).ignore();
    return data;
  }

  void _reload() {
    setState(() {
      _future = _load(force: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jadwal Premier League'),
        actions: [
          IconButton(
            tooltip: 'Cari klub',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SearchPage()),
            ),
            icon: const Icon(Icons.search),
          ),
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: FutureBuilder<FixturesData>(
              future: _future,
              builder: (context, snapshot) {
                // 1. Loading
                if (snapshot.connectionState != ConnectionState.done) {
                  return const LoadingView(
                    message: 'Memuat jadwal pertandingan...',
                  );
                }
                // 2. Error
                if (snapshot.hasError) {
                  final error = snapshot.error;
                  return ErrorView(
                    message: error is ApiException
                        ? error.message
                        : 'Terjadi kesalahan yang tidak terduga.',
                    onRetry: _reload,
                  );
                }
                // 3. Success
                return ListenableBuilder(
                  listenable: AppSettings.instance,
                  builder: (context, _) => _buildContent(snapshot.data!),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(FixturesData data) {
    final p = context.palette;
    final settings = AppSettings.instance;
    final favId = settings.favoriteTeamId;

    // Filter "Klub favorit" hanya muncul bila klub favorit sudah dipilih.
    final filters = MatchFilter.values
        .where((f) => f != MatchFilter.favorite || favId != null)
        .toList();
    if (!filters.contains(_filter)) _filter = MatchFilter.all;

    final matchdays = data.matchdays;
    final selected = _matchday ?? data.currentMatchday;
    final index = matchdays.indexOf(selected);
    final filtered = data
        .byMatchday(selected)
        .where((m) => _filter.accepts(m, favId))
        .toList();
    final items = _groupByDate(filtered);

    return Column(
      children: [
        _MatchdayBar(
          matchday: selected,
          canGoPrev: index > 0,
          canGoNext: index >= 0 && index < matchdays.length - 1,
          onPrev: () => setState(() => _matchday = matchdays[index - 1]),
          onNext: () => setState(() => _matchday = matchdays[index + 1]),
          onPick: () => _pickMatchday(matchdays, selected),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              for (final f in filters)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoicePill(
                    label: f.label,
                    icon: f == MatchFilter.favorite ? Icons.star : null,
                    selected: _filter == f,
                    onTap: () => setState(() => _filter = f),
                  ),
                ),
            ],
          ),
        ),
        const _TimezoneHint(),
        Expanded(
          child: filtered.isEmpty
              ? const EmptyView(
                  message: 'Tidak ada pertandingan dengan filter ini '
                      'di pekan yang dipilih.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final item = items[i];
                    if (item is String) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
                        child: Text(
                          item,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: p.muted,
                          ),
                        ),
                      );
                    }
                    final match = item as MatchModel;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: MatchCard(
                        match: match,
                        favoriteTeamId: favId,
                        hasReminder: settings.hasReminder(match.id),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => MatchDetailPage(match: match),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// Menyisipkan judul tanggal di antara pertandingan.
  List<Object> _groupByDate(List<MatchModel> matches) {
    final fmt = DateFormat('EEEE, d MMMM yyyy', 'id_ID');
    final result = <Object>[];
    String? lastLabel;
    for (final m in matches) {
      final label = fmt.format(m.kickoff);
      if (label != lastLabel) {
        result.add(label);
        lastLabel = label;
      }
      result.add(m);
    }
    return result;
  }

  Future<void> _pickMatchday(List<int> matchdays, int selected) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pilih pekan',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final d in matchdays)
                    ChoicePill(
                      label: '$d',
                      selected: d == selected,
                      onTap: () => Navigator.of(ctx).pop(d),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (picked != null && mounted) {
      setState(() => _matchday = picked);
    }
  }
}

/// [UAS] Keterangan zona waktu dan lokasi pengguna.
class _TimezoneHint extends StatelessWidget {
  const _TimezoneHint();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final now = DateTime.now();
    final offset = now.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final hours = offset.inMinutes.abs() ~/ 60;
    final minutes = offset.inMinutes.abs() % 60;
    final utc = 'UTC$sign$hours${minutes == 0 ? '' : ':$minutes'}';
    final city = AppSettings.instance.location?.city;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          Icon(
            city == null ? Icons.schedule : Icons.place_outlined,
            size: 14,
            color: p.muted,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              city == null
                  ? 'Jam dalam zona waktu perangkat ($utc)'
                  : 'Jam tayang di $city (${now.timeZoneName}, $utc)',
              style: TextStyle(color: p.muted, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchdayBar extends StatelessWidget {
  const _MatchdayBar({
    required this.matchday,
    required this.canGoPrev,
    required this.canGoNext,
    required this.onPrev,
    required this.onNext,
    required this.onPick,
  });

  final int matchday;
  final bool canGoPrev;
  final bool canGoNext;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            tooltip: 'Pekan sebelumnya',
            onPressed: canGoPrev ? onPrev : null,
            icon: const Icon(Icons.chevron_left),
          ),
          InkWell(
            onTap: onPick,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  Text('Pekan ke-$matchday',
                      style: AppTheme.numeric(size: 24)),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Pekan berikutnya',
            onPressed: canGoNext ? onNext : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}
