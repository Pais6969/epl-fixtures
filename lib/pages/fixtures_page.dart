import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/match_model.dart';
import '../services/football_api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/choice_pill.dart';
import '../widgets/match_card.dart';
import '../widgets/state_views.dart';
import 'match_detail_page.dart';

enum MatchFilter { all, upcoming, live, finished }

extension MatchFilterX on MatchFilter {
  String get label => switch (this) {
        MatchFilter.all => 'Semua',
        MatchFilter.upcoming => 'Akan main',
        MatchFilter.live => 'Berlangsung',
        MatchFilter.finished => 'Selesai',
      };

  bool accepts(MatchModel m) => switch (this) {
        MatchFilter.all => true,
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
    _future = widget.service.fetchFixtures();
  }

  void _reload() {
    setState(() {
      _future = widget.service.fetchFixtures();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jadwal Premier League'),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<FixturesData>(
        future: _future,
        builder: (context, snapshot) {
          // 1. Loading
          if (snapshot.connectionState != ConnectionState.done) {
            return const LoadingView(message: 'Memuat jadwal pertandingan...');
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
          return _buildContent(snapshot.data!);
        },
      ),
    );
  }

  Widget _buildContent(FixturesData data) {
    final matchdays = data.matchdays;
    final selected = _matchday ?? data.currentMatchday;
    final index = matchdays.indexOf(selected);
    final filtered =
        data.byMatchday(selected).where(_filter.accepts).toList();
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
              for (final f in MatchFilter.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoicePill(
                    label: f.label,
                    selected: _filter == f,
                    onTap: () => setState(() => _filter = f),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
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
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.muted,
                          ),
                        ),
                      );
                    }
                    final match = item as MatchModel;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: MatchCard(
                        match: match,
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
      backgroundColor: Colors.white,
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
