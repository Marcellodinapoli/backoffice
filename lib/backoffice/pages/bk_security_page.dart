// ================================================================
// IMPORT
// ================================================================
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ================================================================
// MAIN
// ================================================================
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: BkSecurityPage(),
    );
  }
}

// ================================================================
// PAGE
// ================================================================
class BkSecurityPage extends StatelessWidget {
  const BkSecurityPage({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    int crossAxisCount = 3;
    if (width < 1200) crossAxisCount = 2;
    if (width < 800) crossAxisCount = 1;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('security_logs')
              .snapshots(),
          builder: (context, securitySnap) {
            if (securitySnap.connectionState ==
                ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (securitySnap.hasError) {
              return const Center(child: Text("Errore caricamento dati"));
            }

            final logs = securitySnap.data?.docs ?? [];

            // ==============================
            // GLOBAL COUNTERS
            // ==============================
            int failed = 0;
            int suspicious = 0;
            int critical = 0;

            // ==============================
            // SOURCE SPLIT
            // ==============================
            int planetLogs = 0;
            int backofficeLogs = 0;

            for (var d in logs) {
              final data = d.data() as Map<String, dynamic>;
              final type = data['type'];
              final source = data['source'];

              // global
              if (type == 'login_failed') failed++;
              if (type == 'suspicious') suspicious++;
              if (type == 'critical') critical++;

              // source split
              if (source == 'planet') planetLogs++;
              if (source == 'backoffice') backofficeLogs++;
            }

            return FutureBuilder(
              future: Future.wait([
                FirebaseFirestore.instance
                    .collection('pendingLogins')
                    .get(),
                FirebaseFirestore.instance
                    .collection('users')
                    .where('status', isEqualTo: 'blocked')
                    .get(),
              ]).catchError((e) {
                print("Errore sicurezza: $e");
                return [null, null];
              }),
              builder: (context, AsyncSnapshot snap) {

                if (snap.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator());
                }

                int pending = 0;
                int blockedUsers = 0;

                try {
                  if (snap.data != null && snap.data[0] != null) {
                    pending =
                        (snap.data[0] as QuerySnapshot).docs.length;
                  }
                  if (snap.data != null && snap.data[1] != null) {
                    blockedUsers =
                        (snap.data[1] as QuerySnapshot).docs.length;
                  }
                } catch (e) {
                  print("Parse error: $e");
                }

                final items = [
                  _SecurityItem(
                    title: "Login Planet",
                    value: planetLogs.toString(),
                    status: SecurityStatus.safe,
                  ),
                  _SecurityItem(
                    title: "Login BackOffice",
                    value: backofficeLogs.toString(),
                    status: SecurityStatus.safe,
                  ),
                  _SecurityItem(
                    title: "Pending Login",
                    value: pending.toString(),
                    status: pending > 3
                        ? SecurityStatus.warning
                        : SecurityStatus.safe,
                  ),
                  _SecurityItem(
                    title: "Tentativi falliti",
                    value: failed.toString(),
                    status: failed > 5
                        ? SecurityStatus.warning
                        : SecurityStatus.safe,
                  ),
                  _SecurityItem(
                    title: "Utenti bloccati",
                    value: blockedUsers.toString(),
                    status: SecurityStatus.safe,
                  ),
                  _SecurityItem(
                    title: "Eventi critici",
                    value: critical.toString(),
                    status: critical > 0
                        ? SecurityStatus.critical
                        : SecurityStatus.safe,
                  ),
                  _SecurityItem(
                    title: "Dispositivi sospetti",
                    value: suspicious.toString(),
                    status: suspicious > 0
                        ? SecurityStatus.warning
                        : SecurityStatus.safe,
                  ),
                ];

                final overallStatus = critical > 0
                    ? ("Sistema a rischio", Colors.red)
                    : (failed > 10 || suspicious > 3)
                    ? ("Attenzione richiesta", Colors.orange)
                    : ("Sistema sicuro", Colors.green);

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(30),
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Sicurezza Sistema",
                        style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold),
                      ),

                      const SizedBox(height: 40),

                      GridView.builder(
                        shrinkWrap: true,
                        physics:
                        const NeverScrollableScrollPhysics(),
                        itemCount: items.length,
                        gridDelegate:
                        SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 20,
                          mainAxisSpacing: 20,
                          childAspectRatio: 2.4,
                        ),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return _SecurityCard(
                            title: item.title,
                            value: item.value,
                            status: item.status,
                          );
                        },
                      ),

                      const SizedBox(height: 60),

                      const Text(
                        "Stato Generale Sicurezza",
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold),
                      ),

                      const SizedBox(height: 20),

                      _statusBanner(
                        overallStatus.$1,
                        overallStatus.$2,
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// ================================================================
// MODEL
// ================================================================
class _SecurityItem {
  final String title;
  final String value;
  final SecurityStatus status;

  const _SecurityItem({
    required this.title,
    required this.value,
    required this.status,
  });
}

enum SecurityStatus { safe, warning, critical }

// ================================================================
// UI COMPONENTS
// ================================================================
class _SecurityCard extends StatelessWidget {
  final String title;
  final String value;
  final SecurityStatus status;

  const _SecurityCard({
    required this.title,
    required this.value,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    switch (status) {
      case SecurityStatus.safe:
        statusColor = Colors.green;
        break;
      case SecurityStatus.warning:
        statusColor = Colors.orange;
        break;
      case SecurityStatus.critical:
        statusColor = Colors.red;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border:
        Border.all(color: statusColor.withOpacity(0.4)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 10,
            offset: Offset(0, 6),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black54)),

          const SizedBox(height: 12),

          Text(
            value,
            style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: statusColor),
          ),
        ],
      ),
    );
  }
}

Widget _statusBanner(String text, Color color) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: color,
      ),
    ),
  );
}