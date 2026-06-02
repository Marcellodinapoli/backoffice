// lib/backoffice/bk_shell.dart

// -----------------------------------------------------------------------------
// IMPORT
// -----------------------------------------------------------------------------
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../auth/fortress_login_page.dart';

// 🔹 Import pagine
import 'pages/bk_dashboard_page.dart';
import 'pages/bk_users_page.dart';
import 'pages/bk_companies_page.dart';
import 'pages/bk_courses_page.dart';
import 'pages/bk_announcements_page.dart';
import 'pages/bk_statistics_page.dart';
import 'pages/bk_settings_page.dart';
import 'pages/bk_jobs_page.dart';
import 'pages/bk_export_page.dart';
import 'pages/bk_costs_page.dart';
import 'pages/bk_security_page.dart';
import 'pages/bk_roleplay_page.dart';
import 'pages/bk_community_page.dart';
import 'pages/bk_support_page.dart';
import 'pages/bk_job_rules_page.dart';
import 'pages/bk_windows_app_page.dart';

// -----------------------------------------------------------------------------
// PAGE
// -----------------------------------------------------------------------------
class BackOfficeShell extends StatefulWidget {
  const BackOfficeShell({super.key});

  @override
  State<BackOfficeShell> createState() => _BackOfficeShellState();
}

// -----------------------------------------------------------------------------
// STATE
// -----------------------------------------------------------------------------
class _BackOfficeShellState extends State<BackOfficeShell> {

  int _index = 0;

  // ✅ PAGINE ISTANZIATE UNA SOLA VOLTA (FIX LAMPEGGIO)
  late final List<Widget> _pages = const [
    BkDashboardPage(),
    BkUsersPage(),
    BkCompaniesPage(),
    BkCoursesPage(),
    BkRoleplayPage(),
    BkAnnouncementsPage(),
    BkStatisticsPage(),
    BkSettingsPage(),
    BkJobsPage(),
    BkJobRulesPage(), // nuova pagina
    BkExportPage(),
    BkCostsPage(),
    BkSecurityPage(),
    BkCommunityPage(),
    BkSupportPage(),
    BkWindowsAppPage(),
  ];

  final List<String> _titles = const [
    'Dashboard',
    'Utenti',
    'Aziende',
    'Corsi',
    'Role Play',
    'Popup/Annunci',
    'Statistiche',
    'Impostazioni',
    'CreditJob',
    'Consensi job', // nuova voce menu
    'Esporta',
    'Costi',
    'Sicurezza',
    'Community',
    'Assistenza',
    'App Windows',
  ];

  final List<IconData> _icons = const [
    Icons.dashboard_outlined,
    Icons.people_outline,
    Icons.business_outlined,
    Icons.menu_book_outlined,
    Icons.record_voice_over_outlined,
    Icons.campaign_outlined,
    Icons.bar_chart_outlined,
    Icons.settings_outlined,
    Icons.work_outline,
    Icons.rule_outlined, // icona regolamento
    Icons.download_outlined,
    Icons.euro_outlined,
    Icons.security_outlined,
    Icons.forum_outlined,
    Icons.support_agent_outlined,
    Icons.desktop_windows_outlined,
  ];

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {

    final safeIndex = _index.clamp(0, _pages.length - 1).toInt();
    final currentTitle = _titles[safeIndex];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(currentTitle),
      body: Row(
        children: [

          // ✅ FIX DEFINITIVO LAMPEGGIO
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1300),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: IndexedStack(
                    index: safeIndex,
                    children: _pages,
                  ),
                ),
              ),
            ),
          ),

          const VerticalDivider(width: 1),
          _buildSideMenu(safeIndex),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UI - APPBAR
  // ---------------------------------------------------------------------------
  AppBar _buildAppBar(String currentTitle) {
    return AppBar(
      backgroundColor: const Color(0xFF1565C0),
      elevation: 0,
      title: Row(
        children: [
          const Text(
            "BackOffice",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 1,
            height: 20,
            color: Colors.white.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 12),
          Text(
            currentTitle,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.white,
              fontSize: 16,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Logout',
          onPressed: () async {
            await FirebaseAuth.instance.signOut();
            if (mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) =>
                  const FortressLoginPage(),
                ),
                    (route) => false,
              );
            }
          },
          icon: const Icon(Icons.logout, color: Colors.white),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // UI - MENU
  // ---------------------------------------------------------------------------
  Widget _buildSideMenu(int safeIndex) {
    return Container(
      width: 270,
      color: const Color(0xFFF7F9FB),
      child: ListView.builder(
        padding:
        const EdgeInsets.symmetric(vertical: 24),
        itemCount: _titles.length,
        itemBuilder: (context, i) {

          final isSelected = i == safeIndex;

          return InkWell(
            onTap: () {
              setState(() {
                _index = i;
              });
            },
            child: Container(
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF1565C0)
                    .withValues(alpha: 0.08)
                    : Colors.transparent,
                border: Border(
                  left: BorderSide(
                    color: isSelected
                        ? const Color(0xFF1565C0)
                        : Colors.transparent,
                    width: 4,
                  ),
                ),
              ),
              padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14),
              child: Row(
                children: [
                  Icon(
                    _icons[i],
                    size: 20,
                    color: isSelected
                        ? const Color(0xFF1565C0)
                        : Colors.grey[700],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      _titles[i],
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: isSelected
                            ? const Color(0xFF1565C0)
                            : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}