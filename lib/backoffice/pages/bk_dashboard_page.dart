import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/user_account_status.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: BkDashboardPage(),
    );
  }
}

class BkDashboardPage extends StatelessWidget {
  const BkDashboardPage({super.key});

  Future<int> _countCollection(String collection) async {
    final snap = await FirebaseFirestore.instance
        .collection(collection)
        .count()
        .get();
    return snap.count ?? 0;
  }

  Future<Map<String, int>> _countUsersDetailed() async {
    final col = FirebaseFirestore.instance.collection('users');

    final total = await col.count().get();
    final active = await col.where('status', isEqualTo: 'active').count().get();
    final blocked = await col
        .where('status', whereIn: UserAccountStatus.blockedStatusValues)
        .count()
        .get();
    final deleted = await col.where('status', isEqualTo: 'deleted').count().get();

    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);

    final month = await col
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .count()
        .get();

    return {
      "total": total.count ?? 0,
      "active": active.count ?? 0,
      "blocked": blocked.count ?? 0,
      "deleted": deleted.count ?? 0,
      "month": month.count ?? 0,
    };
  }

  Future<Map<String, int>> _countJobOffersDetailed() async {
    final col = FirebaseFirestore.instance.collection('job_offers');

    final total = await col.count().get();

    final active = await col
        .where('status', isEqualTo: 'approved')
        .where('online', isEqualTo: true)
        .count()
        .get();

    final pending = await col
        .where('status', isEqualTo: 'pending')
        .count()
        .get();

    final blocked = await col
        .where('status', isEqualTo: 'blocked')
        .count()
        .get();

    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);

    final month = await col
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .count()
        .get();

    final expired = await col
        .where('expiryDate', isLessThan: Timestamp.fromDate(now))
        .count()
        .get();

    return {
      "total": total.count ?? 0,
      "active": active.count ?? 0,
      "pending": pending.count ?? 0,
      "blocked": blocked.count ?? 0,
      "month": month.count ?? 0,
      "expired": expired.count ?? 0,
    };
  }

  Future<int> _countCompanies() async {
    return _countCollection('companies');
  }

  Future<int> _countRoleplay() async {
    final snap = await FirebaseFirestore.instance
        .collection('roleplay')
        .count()
        .get();
    return snap.count ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    int crossAxisCount = 3;
    if (width < 1200) crossAxisCount = 2;
    if (width < 800) crossAxisCount = 1;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: SafeArea(
        child: FutureBuilder(
          future: Future.wait([
            _countUsersDetailed(),
            _countCompanies(),
            _countCollection('courses'),
            _countCollection('job_applications'),
            _countJobOffersDetailed(),
            _countRoleplay(),
          ]),
          builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final users = snapshot.data![0] as Map<String, int>;
            final companies = snapshot.data![1] as int;
            final courses = snapshot.data![2] as int;
            final applications = snapshot.data![3] as int;
            final jobs = snapshot.data![4] as Map<String, int>;
            final roleplay = snapshot.data![5] as int;

            final cards = [
              _DashboardCardData(
                title: "Utenti",
                value: users["total"].toString(),
                accentColor: Colors.blue,
                details: [
                  _DetailRow("Attivi", users["active"]!, Colors.green),
                  _DetailRow("Bloccati/Standby", users["blocked"]!, Colors.orange),
                  _DetailRow("Cancellati", users["deleted"]!, Colors.red),
                  _DetailRow("Mese", users["month"]!, Colors.amber),
                ],
              ),
              _DashboardCardData(
                title: "Aziende",
                value: companies.toString(),
                accentColor: Colors.blue,
              ),
              _DashboardCardData(
                title: "Corsi",
                value: courses.toString(),
                accentColor: Colors.blue,
              ),
              _DashboardCardData(
                title: "Candidature",
                value: applications.toString(),
                accentColor: Colors.blue,
              ),
              _DashboardCardData(
                title: "Offerte Job",
                value: jobs["total"].toString(),
                accentColor: Colors.blue,
                details: [
                  _DetailRow("Attive", jobs["active"]!, Colors.green),
                  _DetailRow("Pending", jobs["pending"]!, Colors.orange),
                  _DetailRow("Bloccate", jobs["blocked"]!, Colors.red),
                  _DetailRow("Mese", jobs["month"]!, Colors.amber),
                  _DetailRow("Scadute", jobs["expired"]!, Colors.grey),
                ],
              ),
              _DashboardCardData(
                title: "RolePlay",
                value: roleplay.toString(),
                accentColor: Colors.blue,
              ),
            ];

            return SingleChildScrollView(
              padding: const EdgeInsets.all(30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Dashboard",
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 40),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: cards.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 20,
                      mainAxisSpacing: 20,
                      mainAxisExtent: 252,
                    ),
                    itemBuilder: (context, index) {
                      final card = cards[index];
                      return _DashboardCard(
                        title: card.title,
                        value: card.value,
                        accentColor: card.accentColor,
                        details: card.details,
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DashboardCardData {
  final String title;
  final String value;
  final Color accentColor;
  final List<_DetailRow>? details;

  const _DashboardCardData({
    required this.title,
    required this.value,
    required this.accentColor,
    this.details,
  });
}

class _DetailRow {
  final String label;
  final int value;
  final Color color;

  const _DetailRow(this.label, this.value, this.color);
}

class _DashboardCard extends StatelessWidget {
  final String title;
  final String value;
  final Color accentColor;
  final List<_DetailRow>? details;

  const _DashboardCard({
    required this.title,
    required this.value,
    required this.accentColor,
    this.details,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Container(
        padding: const EdgeInsets.all(22),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accentColor.withValues(alpha: 0.4)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 10,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: accentColor,
              ),
            ),
            if (details != null && details!.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 6),
              Expanded(
                child: Column(
                  children: details!.map(
                    (d) => Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            d.label,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                          Text(
                            "${d.value}",
                            style: TextStyle(
                              fontSize: 12,
                              color: d.color,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}