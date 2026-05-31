// lib/backoffice/pages/bk_jobs_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BkJobsPage extends StatefulWidget {
  const BkJobsPage({super.key});

  @override
  State<BkJobsPage> createState() => _BkJobsPageState();
}

class _BkJobsPageState extends State<BkJobsPage> {

  // ---------------------------------------------------------------------------
  // CONFIG
  // ---------------------------------------------------------------------------

  final CollectionReference _jobsRef =
  FirebaseFirestore.instance.collection('job_offers');

  // ---------------------------------------------------------------------------
// SERVICES
// ---------------------------------------------------------------------------

  Future<void> _approveJob(String id) async {
    final now = DateTime.now();
    final expiry = now.add(const Duration(days: 30));

    await _jobsRef.doc(id).update({
      'status': 'approved',
      'online': true,
      'approvedAt': FieldValue.serverTimestamp(),
      'createdAt': Timestamp.fromDate(now),
      'expiryDate': Timestamp.fromDate(expiry),
    });
  }

  Future<void> _rejectJob(String id) async {
    await _jobsRef.doc(id).update({
      'status': 'rejected',
      'online': false,
      'rejectedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _blockJob(String id) async {
    await _jobsRef.doc(id).update({
      'status': 'blocked',
      'online': false,
      'blockedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _unblockJob(String id) async {
    final now = DateTime.now();
    final expiry = now.add(const Duration(days: 30));

    await _jobsRef.doc(id).update({
      'status': 'approved',
      'online': true,
      'unblockedAt': FieldValue.serverTimestamp(),
      'createdAt': Timestamp.fromDate(now),
      'expiryDate': Timestamp.fromDate(expiry),
    });
  }

// ---------------------------------------------------------------------------
// BUILD
// ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: StreamBuilder<QuerySnapshot>(
        stream: _jobsRef.orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: Text("Caricamento..."));
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Errore: ${snapshot.error}",
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "Nessuna offerta di lavoro disponibile.",
                style: TextStyle(color: Colors.black54),
              ),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              final id = docs[i].id;

              final String title = data['title'] ?? '';
              final String companyId = data['companyId'] ?? '';
              final String location = data['location'] ?? '';
              final String contract = data['contractType'] ?? '';
              final String education = data['education'] ?? '';
              final String experience = data['experience'] ?? '';
              final String benefits = data['benefits'] ?? '';
              final String description = data['description'] ?? '';
              final String schedule = data['schedule'] ?? '';
              final String workMode = data['workMode'] ?? '';
              final int qualityScore = data['qualityScore'] ?? 0;
              final int applicationsCount = data['applicationsCount'] ?? 0;
              final bool online = data['online'] ?? false;

              final int? salaryFrom = data['salaryFrom'];
              final int? salaryTo = data['salaryTo'];
              final int? salaryMin = data['salaryMin'];
              final int? salaryMax = data['salaryMax'];

              final List<dynamic> skillsRaw = data['skills'] ?? [];
              final List<String> skills = skillsRaw
                  .map((s) => (s['value'] ?? '').toString())
                  .where((e) => e.isNotEmpty)
                  .toList();

              String status = data['status'] ?? 'pending';

              final Timestamp? createdTs = data['createdAt'];
              final String createdDate =
              createdTs != null ? _formatDate(createdTs.toDate()) : '';

              final Timestamp? expiryTs = data['expiryDate'];
              final DateTime? expiryDateRaw =
              expiryTs != null ? expiryTs.toDate() : null;

              final String expiryDate =
              expiryDateRaw != null ? _formatDate(expiryDateRaw) : '';

              final bool isExpired =
                  expiryDateRaw != null &&
                      expiryDateRaw.isBefore(DateTime.now());

              if (isExpired && status == 'approved') {
                status = 'expired';
              }

              final bool isPending = status == 'pending';
              final bool isBlocked = status == 'blocked';

              return Card(
                color: status == 'pending'
                    ? Colors.orange.shade50
                    : status == 'approved'
                    ? Colors.green.shade50
                    : status == 'blocked'
                    ? Colors.grey.shade300
                    : status == 'expired'
                    ? Colors.red.shade100
                    : Colors.red.shade50,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),

                      const SizedBox(height: 6),

                      FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('companies')
                            .doc(companyId)
                            .get(),
                        builder: (context, companySnap) {
                          if (!companySnap.hasData) {
                            return const Text(
                              "Azienda: ...",
                              style: TextStyle(fontWeight: FontWeight.w600),
                            );
                          }

                          final companyData =
                          companySnap.data!.data() as Map<String, dynamic>?;

                          final companyName =
                              companyData?['companyName'] ?? '—';

                          return Text(
                            "Azienda: $companyName",
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          );
                        },
                      ),

                      Text(location),

                      const SizedBox(height: 12),

                      Text("Contratto: $contract"),
                      if (schedule.isNotEmpty)
                        Text("Orario: $schedule"),
                      if (workMode.isNotEmpty)
                        Text("Modalità: $workMode"),
                      if (education.isNotEmpty)
                        Text("Formazione richiesta: $education"),
                      if (experience.isNotEmpty)
                        Text("Esperienza richiesta: $experience"),

                      if (salaryFrom != null || salaryTo != null)
                        Text("Stipendio: ${salaryFrom ?? '-'} - ${salaryTo ?? '-'}"),

                      if (salaryMin != null || salaryMax != null)
                        Text("RAL: ${salaryMin ?? '-'} - ${salaryMax ?? '-'}"),

                      if (skills.isNotEmpty)
                        Text("Competenze: ${skills.join(', ')}"),

                      if (benefits.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Text(
                          "Benefit:",
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(benefits),
                      ],

                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Text(
                          "Descrizione:",
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(description),
                      ],

                      const SizedBox(height: 12),

                      Text(
                        "Pubblicato il $createdDate"
                            "${expiryDate.isNotEmpty ? " • Scade il $expiryDate" : ""}",
                        style: const TextStyle(fontSize: 12),
                      ),

                      const SizedBox(height: 4),

                      Text("Candidature: $applicationsCount"),
                      Text("Qualità annuncio: $qualityScore%"),
                      Text("Online: ${online ? "Si" : "No"}"),

                      const SizedBox(height: 4),

                      Text(
                        "Stato: $status",
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      const SizedBox(height: 12),

                      Row(
                        children: [

                          if (isPending) ...[
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                              ),
                              onPressed: () => _approveJob(id),
                              icon: const Icon(Icons.check, size: 18),
                              label: const Text("Approva"),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                              onPressed: () => _rejectJob(id),
                              icon: const Icon(Icons.close, size: 18),
                              label: const Text("Rifiuta"),
                            ),
                            const SizedBox(width: 12),
                          ],

                          if (isBlocked)
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                              ),
                              onPressed: () => _unblockJob(id),
                              icon: const Icon(Icons.lock_open, size: 18),
                              label: const Text("Sblocca"),
                            )
                          else
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black87,
                              ),
                              onPressed: () => _blockJob(id),
                              icon: const Icon(Icons.block, size: 18),
                              label: const Text("Blocca pubblicazione"),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UTIL
  // ---------------------------------------------------------------------------

  String _formatDate(DateTime d) {
    return "${d.day.toString().padLeft(2, '0')}/"
        "${d.month.toString().padLeft(2, '0')}/"
        "${d.year}";
  }
}