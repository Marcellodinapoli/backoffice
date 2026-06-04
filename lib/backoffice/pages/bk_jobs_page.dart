// lib/backoffice/pages/bk_jobs_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'bk_company_jobs_page.dart';

class BkJobsPage extends StatelessWidget {
  const BkJobsPage({super.key});

  static const _expiringWithinDays = 7;

  Color _statusColor(String status) {
    switch (status) {
      case "active":
        return Colors.green;
      case "blocked":
        return Colors.red;
      case "standby":
        return Colors.orange;
      default:
        return Colors.orange;
    }
  }

  String _resolveJobStatus(Map<String, dynamic> data) {
    String status = data['status'] ?? 'pending';
    final Timestamp? expiryTs = data['expiryDate'];
    final DateTime? expiryDateRaw = expiryTs?.toDate();
    final bool isExpired = expiryDateRaw != null &&
        expiryDateRaw.isBefore(DateTime.now());

    if (isExpired && status == 'approved') {
      status = 'expired';
    }
    return status;
  }

  _CompanyJobStats _statsForCompany(
    List<QueryDocumentSnapshot> allJobs,
    String companyId,
  ) {
    final stats = _CompanyJobStats();
    final now = DateTime.now();
    final expiringThreshold = now.add(
      const Duration(days: _expiringWithinDays),
    );

    for (final doc in allJobs) {
      final data = doc.data() as Map<String, dynamic>;
      if ((data['companyId'] ?? '') != companyId) continue;

      stats.total++;

      final status = _resolveJobStatus(data);
      final Timestamp? expiryTs = data['expiryDate'];
      final DateTime? expiry = expiryTs?.toDate();

      switch (status) {
        case 'pending':
          stats.pending++;
          break;
        case 'approved':
          stats.published++;
          if (expiry != null &&
              expiry.isAfter(now) &&
              !expiry.isAfter(expiringThreshold)) {
            stats.expiring++;
          }
          break;
        case 'blocked':
          stats.blocked++;
          break;
        case 'expired':
          stats.expired++;
          break;
        case 'rejected':
          stats.rejected++;
          break;
      }
    }

    return stats;
  }

  Widget _statRow(String label, int value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          SizedBox(
            width: 132,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            "$value",
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final companiesStream =
        FirebaseFirestore.instance.collection('companies').snapshots();
    final jobsStream = FirebaseFirestore.instance
        .collection('job_offers')
        .snapshots();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: StreamBuilder<QuerySnapshot>(
        stream: companiesStream,
        builder: (context, companiesSnap) {
          if (companiesSnap.connectionState == ConnectionState.waiting &&
              !companiesSnap.hasData) {
            return const Center(child: Text("Caricamento..."));
          }

          if (companiesSnap.hasError) {
            return Center(
              child: Text(
                "Errore: ${companiesSnap.error}",
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          return StreamBuilder<QuerySnapshot>(
            stream: jobsStream,
            builder: (context, jobsSnap) {
              if (jobsSnap.connectionState == ConnectionState.waiting &&
                  !jobsSnap.hasData) {
                return const Center(child: Text("Caricamento..."));
              }

              if (jobsSnap.hasError) {
                return Center(
                  child: Text(
                    "Errore: ${jobsSnap.error}",
                    style: const TextStyle(color: Colors.red),
                  ),
                );
              }

              final companies = companiesSnap.data?.docs ?? [];
              final allJobs = jobsSnap.data?.docs ?? [];

              if (companies.isEmpty) {
                return const Center(
                  child: Text(
                    "Nessuna azienda disponibile.",
                    style: TextStyle(color: Colors.black54),
                  ),
                );
              }

              return ListView.separated(
                itemCount: companies.length,
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (context, index) {
                  final companyDoc = companies[index];
                  final companyId = companyDoc.id;
                  final data =
                      companyDoc.data() as Map<String, dynamic>;

                  final companyName =
                      data['companyName'] ?? 'Senza nome';
                  final email = data['email'] ?? 'Nessuna email';
                  final fallbackStatus = data['status'] ?? 'pending';

                  final stats = _statsForCompany(allJobs, companyId);

                  return StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(companyId)
                        .snapshots(),
                    builder: (context, userSnapshot) {
                      String status = fallbackStatus;

                      if (userSnapshot.hasData &&
                          userSnapshot.data!.exists) {
                        final userData = userSnapshot.data!.data()
                            as Map<String, dynamic>?;
                        if (userData != null &&
                            userData['status'] != null) {
                          status = userData['status'];
                        }
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Card(
                          elevation: 1.5,
                          color: const Color(0xFFF5F5F5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => BkCompanyJobsPage(
                                    companyId: companyId,
                                    companyName: companyName,
                                  ),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                20,
                                20,
                                18,
                              ),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.circle,
                                        color: _statusColor(status),
                                        size: 12,
                                      ),
                                      const SizedBox(width: 10),
                                      const Icon(
                                        Icons.business_outlined,
                                        color: Colors.blueGrey,
                                        size: 22,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          companyName,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.black,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    email,
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  _statRow(
                                    "Offerte totali",
                                    stats.total,
                                    Colors.blue,
                                  ),
                                  _statRow(
                                    "Pubblicate",
                                    stats.published,
                                    Colors.green,
                                  ),
                                  _statRow(
                                    "In scadenza",
                                    stats.expiring,
                                    Colors.orange,
                                  ),
                                  _statRow(
                                    "Scadute",
                                    stats.expired,
                                    Colors.red,
                                  ),
                                  _statRow(
                                    "In attesa",
                                    stats.pending,
                                    Colors.amber.shade800,
                                  ),
                                  _statRow(
                                    "Bloccate",
                                    stats.blocked,
                                    Colors.grey.shade700,
                                  ),
                                  const SizedBox(height: 18),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF1565C0),
                                        foregroundColor: Colors.white,
                                        padding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: 10,
                                        ),
                                        shape: const StadiumBorder(),
                                        elevation: 0,
                                      ),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                BkCompanyJobsPage(
                                              companyId: companyId,
                                              companyName: companyName,
                                            ),
                                          ),
                                        );
                                      },
                                      child: const Text("Dettagli"),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _CompanyJobStats {
  int total = 0;
  int published = 0;
  int expiring = 0;
  int expired = 0;
  int pending = 0;
  int blocked = 0;
  int rejected = 0;
}
