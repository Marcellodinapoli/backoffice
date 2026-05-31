import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
    final blocked = await col.where('status', isEqualTo: 'blocked').count().get();
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
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .where('type', isEqualTo: 'company')
        .count()
        .get();
    return snap.count ?? 0;
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
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              const Text(
                "Dashboard",
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 40),

              FutureBuilder(
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

                  return Wrap(
                    spacing: 20,
                    runSpacing: 20,
                    children: [

                      _bigCard(
                        title: "Utenti",
                        mainValue: users["total"].toString(),
                        children: [
                          _row("Attivi", users["active"], Colors.green),
                          _row("Bloccati", users["blocked"], Colors.orange),
                          _row("Cancellati", users["deleted"], Colors.red),
                          _row("Mese", users["month"], Colors.amber),
                        ],
                      ),

                      _bigCard(
                        title: "Aziende",
                        mainValue: companies.toString(),
                        children: [
                          _row("Totali", companies, Colors.blue),
                          _row("", 0, Colors.transparent),
                          _row("", 0, Colors.transparent),
                          _row("", 0, Colors.transparent),
                        ],
                      ),

                      _bigCard(
                        title: "Corsi",
                        mainValue: courses.toString(),
                        children: [
                          _row("Disponibili", courses, Colors.blue),
                          _row("", 0, Colors.transparent),
                          _row("", 0, Colors.transparent),
                          _row("", 0, Colors.transparent),
                        ],
                      ),

                      _bigCard(
                        title: "Candidature",
                        mainValue: applications.toString(),
                        children: [
                          _row("Totali", applications, Colors.blue),
                          _row("", 0, Colors.transparent),
                          _row("", 0, Colors.transparent),
                          _row("", 0, Colors.transparent),
                        ],
                      ),

                      _bigCard(
                        title: "Offerte Job",
                        mainValue: jobs["total"].toString(),
                        children: [
                          _row("Attive", jobs["active"], Colors.green),
                          _row("Pending", jobs["pending"], Colors.orange),
                          _row("Bloccate", jobs["blocked"], Colors.red),
                          _row("Mese", jobs["month"], Colors.amber),
                          _row("Scadute", jobs["expired"], Colors.grey),
                        ],
                      ),

                      _bigCard(
                        title: "RolePlay",
                        mainValue: roleplay.toString(),
                        children: [
                          _row("Totali", roleplay, Colors.blue),
                          _row("", 0, Colors.transparent),
                          _row("", 0, Colors.transparent),
                          _row("", 0, Colors.transparent),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _bigCard({
    required String title,
    required String mainValue,
    required List<Widget> children,
  }) {
    return Container(
      width: 300,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 10,
            offset: Offset(0, 6),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          Text(title,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),

          const SizedBox(height: 10),

          Text(
            mainValue,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 16),

          ...children,
        ],
      ),
    );
  }

  static Widget _row(String label, int? value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            "${value ?? 0}",
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          )
        ],
      ),
    );
  }
}