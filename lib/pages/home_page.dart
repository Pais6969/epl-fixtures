import 'package:flutter/material.dart';

import '../services/football_api_service.dart';
import 'fixtures_page.dart';
import 'me_page.dart';
import 'standings_page.dart';
import 'stats_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FootballApiService _service = FootballApiService.shared;
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack menjaga state tiap tab, jadi data tidak diminta ulang
      // setiap kali pengguna berpindah tab (hemat batas request API).
      body: IndexedStack(
        index: _index,
        children: [
          FixturesPage(service: _service),
          StandingsPage(service: _service),
          StatsPage(service: _service),
          const MePage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Jadwal',
          ),
          NavigationDestination(
            icon: Icon(Icons.leaderboard_outlined),
            selectedIcon: Icon(Icons.leaderboard),
            label: 'Klasemen',
          ),
          // [UAS] Tab baru
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Statistik',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Saya',
          ),
        ],
      ),
    );
  }
}
