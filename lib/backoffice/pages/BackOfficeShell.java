import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../auth/fortress_login_page.dart';

// 🔹 Import pagine (ora in lib/backoffice/pages)
import 'pages/bk_dashboard_page.dart';
import 'pages/bk_users_page.dart';
import 'pages/bk_courses_page.dart';
import 'pages/bk_announcements_page.dart';
import 'pages/bk_statistics_page.dart';
import 'pages/bk_settings_page.dart';
import 'pages/bk_jobs_page.dart';
import 'pages/bk_export_page.dart';
import 'pages/bk_costs_page.dart';
import 'pages/bk_security_page.dart';
import 'pages/bk_roleplay_page.dart';

/// Shell del Back-office: menu laterale (a destra) + area contenuti.
class BackOfficeShell extends StatefulWidget {
  const BackOfficeShell({super.key});

  @override
  State<BackOfficeShell> createState() => _BackOfficeShellState();
}

class _BackOfficeShellState extends State<BackOfficeShell> {
  int _index = 0;

  final List<String> _titles = const [
    'Dashboard',
    'Utenti',
    'Corsi',
    'Role Play',
    'Popup/Annunci',
    'Statistiche',
    'Impostazioni',
    'CreditJob',
    'Esporta',
    'Monitoraggio Costi',
    'Sicurezza',
  ];

  @override
  Widget build(BuildContext context) {
    final pages = _pages();
    final safeIndex = _index.clamp(0, pages.length - 1);

    final currentTitle = _titles[safeIndex];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        title: const Text(
          "Backoffice",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Popup mirato',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Azione popup mirato (stub)')),
              );
            },
            icon: const Icon(Icons.campaign_outlined, color: Colors.white),
          ),
          IconButton(
            tooltip: 'Logout',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                      builder: (context) => const FortressLoginPage()),
                  (route) => false,
                );
              }
            },
            icon: const Icon(Icons.logout, color: Colors.white),
          ),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1300),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentTitle,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(child: pages[safeIndex]),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const VerticalDivider(width: 1),

          SizedBox(
            width: 150,
            child: Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight:
                        MediaQuery.of(context).size.height - kToolbarHeight,
                  ),
                  child: IntrinsicHeight(
                    child: NavigationRail(
                      backgroundColor: const Color(0xFFF5F5F5),
                      selectedIndex: safeIndex,
                      onDestinationSelected: (i) => setState(() => _index = i),
                      labelType: NavigationRailLabelType.all,
                      minWidth: 100,
                      groupAlignment: -1.0,
                      destinations: _navDestinations(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<NavigationRailDestination> _navDestinations() => const [
        NavigationRailDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: Text('Dashboard'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: Text('Utenti'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.menu_book_outlined),
          selectedIcon: Icon(Icons.menu_book),
          label: Text('Corsi'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.record_voice_over_outlined),
          selectedIcon: Icon(Icons.record_voice_over),
          label: Text('Role Play'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.campaign_outlined),
          selectedIcon: Icon(Icons.campaign),
          label: Text('Popup/Annunci'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.query_stats_outlined),
          selectedIcon: Icon(Icons.query_stats),
          label: Text('Statistiche'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings),
          label: Text('Impostazioni'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.work_outline),
          selectedIcon: Icon(Icons.work),
          label: Text('CreditJob'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.file_upload_outlined),
          selectedIcon: Icon(Icons.file_upload),
          label: Text('Esporta'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.savings_outlined),
          selectedIcon: Icon(Icons.savings),
          label: Text('Costi'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.security_outlined),
          selectedIcon: Icon(Icons.security),
          label: Text('Sicurezza'),
        ),
      ];

  List<Widget> _pages() => const [
        BkDashboardPage(),
        BkUsersPage(),
        BkCoursesPage(),
        BkRoleplayPage(),
        BkAnnouncementsPage(),
        BkStatisticsPage(),
        BkSettingsPage(),
        BkJobsPage(),
        BkExportPage(),
        BkCostsPage(),
        BkSecurityPage(),
      ];
}
