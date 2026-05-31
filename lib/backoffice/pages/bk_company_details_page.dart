// -----------------------------------------------------------------------------
// IMPORT
// -----------------------------------------------------------------------------
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:backoffice/backoffice/widgets/bk_impaginazione_secondaria.dart';

// -----------------------------------------------------------------------------
// PAGE
// -----------------------------------------------------------------------------
class BkCompanyDetailsPage extends StatelessWidget {
  final String companyId;

  const BkCompanyDetailsPage({
    super.key,
    required this.companyId,
  });

  // ---------------------------------------------------------------------------
  // UI HELPERS
  // ---------------------------------------------------------------------------
  Color _statusColor(String status) {
    switch (status) {
      case "active":
        return Colors.green;
      case "blocked":
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 160,
            child: Text(
              "$label:",
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ACTIONS
  // ---------------------------------------------------------------------------
  Future<void> _blockCompany(
      BuildContext context,
      DocumentReference companyRef,
      String companyCode,
      ) async {
    final controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Blocca Azienda"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: "Motivazione blocco",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Annulla"),
          ),
          ElevatedButton(
            onPressed: () async {
              final reason = controller.text.trim();

              await companyRef.update({
                "status": "blocked",
                "blockedReason": reason,
                "blockedAt": FieldValue.serverTimestamp(),
              });

              final users = await FirebaseFirestore.instance
                  .collection('users')
                  .where('companyCode', isEqualTo: companyCode)
                  .get();

              final batch = FirebaseFirestore.instance.batch();

              for (var doc in users.docs) {
                batch.update(doc.reference, {
                  "status": "blocked",
                });
              }

              await batch.commit();

              Navigator.pop(context);
            },
            child: const Text("Conferma"),
          ),
        ],
      ),
    );
  }

  Future<void> _activateCompany(
      DocumentReference companyRef,
      String companyCode,
      ) async {
    await companyRef.update({
      "status": "active",
      "blockedReason": FieldValue.delete(),
      "blockedAt": FieldValue.delete(),
      "activatedAt": FieldValue.serverTimestamp(),
    });

    final users = await FirebaseFirestore.instance
        .collection('users')
        .where('companyCode', isEqualTo: companyCode)
        .get();

    final batch = FirebaseFirestore.instance.batch();

    for (var doc in users.docs) {
      batch.update(doc.reference, {
        "status": "active",
      });
    }

    await batch.commit();
  }

// ---------------------------------------------------------------------------
// BUILD
// ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final companyRef =
    FirebaseFirestore.instance.collection('companies').doc(companyId);

    return ImpaginazioneSecondariaBk(
      pageTitle: "Dettaglio Azienda",
      body: StreamBuilder<DocumentSnapshot>(
        stream: companyRef.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.data!.exists) {
            return const Center(child: Text("Azienda non trovata"));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;

          final companyCode = data['companyCode'] ?? '';
          final companyName = data['companyName'] ?? '';
          final email = data['email'] ?? '';
          final phone = data['phone'] ?? '';
          final piva = data['piva'] ?? '';
          final website = data['website'] ?? '';
          final referencePerson = data['referencePerson'] ?? '';
          final referenceRole = data['referenceRole'] ?? '';
          final fallbackStatus = data['status'] ?? 'pending';
          final blockedReason = data['blockedReason'];

          // ✅ NUOVO: data blocco
          final blockedAt = data['blockedAt'];
          final blockedDate = blockedAt != null
              ? (blockedAt as Timestamp).toDate()
              : null;

          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(companyId)
                .snapshots(),
            builder: (context, userSnapshot) {
              String status = fallbackStatus;

              if (userSnapshot.hasData && userSnapshot.data!.exists) {
                final userData =
                userSnapshot.data!.data() as Map<String, dynamic>?;
                if (userData != null && userData['status'] != null) {
                  status = userData['status'];
                }
              }

              return SingleChildScrollView(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Card(
                          elevation: 1.5,
                          color: const Color(0xFFF5F5F5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Padding(
                            padding:
                            const EdgeInsets.fromLTRB(20, 20, 20, 18),
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.circle,
                                        color: _statusColor(status),
                                        size: 14),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        companyName,
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight:
                                          FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    if (status == "blocked")
                                      ElevatedButton(
                                        style:
                                        ElevatedButton.styleFrom(
                                          backgroundColor:
                                          Colors.green,
                                          shape:
                                          const StadiumBorder(),
                                        ),
                                        onPressed: () =>
                                            _activateCompany(
                                                companyRef,
                                                companyCode),
                                        child:
                                        const Text("Attiva"),
                                      )
                                    else
                                      ElevatedButton(
                                        style:
                                        ElevatedButton.styleFrom(
                                          backgroundColor:
                                          Colors.red,
                                          shape:
                                          const StadiumBorder(),
                                        ),
                                        onPressed: () =>
                                            _blockCompany(
                                                context,
                                                companyRef,
                                                companyCode),
                                        child:
                                        const Text("Blocca"),
                                      ),
                                  ],
                                ),

                                // ✅ BLOCCO INFO COMPLETO
                                if (status == "blocked") ...[
                                  if (blockedDate != null)
                                    Padding(
                                      padding:
                                      const EdgeInsets.only(top: 8),
                                      child: Text(
                                        "Bloccato il: ${blockedDate.day.toString().padLeft(2, '0')}/"
                                            "${blockedDate.month.toString().padLeft(2, '0')}/"
                                            "${blockedDate.year} "
                                            "${blockedDate.hour.toString().padLeft(2, '0')}:"
                                            "${blockedDate.minute.toString().padLeft(2, '0')}",
                                        style: const TextStyle(
                                            color: Colors.red),
                                      ),
                                    ),
                                  if (blockedReason != null &&
                                      blockedReason
                                          .toString()
                                          .isNotEmpty)
                                    Padding(
                                      padding:
                                      const EdgeInsets.only(top: 4),
                                      child: Text(
                                        "Motivo blocco: $blockedReason",
                                        style: const TextStyle(
                                            color: Colors.red),
                                      ),
                                    ),
                                ],

                                const SizedBox(height: 18),
                                _infoRow("Company Code",
                                    companyCode),
                                _infoRow("Email", email),
                                _infoRow("Telefono", phone),
                                _infoRow("P.IVA", piva),
                                _infoRow("Website", website),
                                _infoRow("Referente",
                                    referencePerson),
                                _infoRow("Ruolo Referente",
                                    referenceRole),
                                _infoRow("Status", status),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        const Text(
                          "Collaboratori collegati",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('users')
                              .where('companyCode',
                              isEqualTo: companyCode)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const Center(
                                  child:
                                  CircularProgressIndicator());
                            }

                            final collaborators =
                                snapshot.data!.docs;

                            if (collaborators.isEmpty) {
                              return const Text(
                                "Nessun collaboratore collegato",
                                style: TextStyle(
                                    color: Colors.black54),
                              );
                            }

                            return ListView.builder(
                              shrinkWrap: true,
                              physics:
                              const NeverScrollableScrollPhysics(),
                              itemCount: collaborators.length,
                              itemBuilder: (context, index) {
                                final user =
                                collaborators[index].data()
                                as Map<String, dynamic>;

                                final name =
                                    user['name'] ?? 'Senza nome';
                                final email =
                                    user['email'] ?? '';
                                final status =
                                    user['status'] ?? 'pending';

                                return Padding(
                                  padding:
                                  const EdgeInsets.symmetric(
                                      vertical: 8),
                                  child: Card(
                                    elevation: 1.5,
                                    color:
                                    const Color(0xFFF5F5F5),
                                    shape:
                                    RoundedRectangleBorder(
                                      borderRadius:
                                      BorderRadius.circular(
                                          16),
                                    ),
                                    child: ListTile(
                                      leading: Icon(
                                        Icons.circle,
                                        color:
                                        _statusColor(status),
                                        size: 12,
                                      ),
                                      title: Text(
                                        name,
                                        style:
                                        const TextStyle(
                                          fontWeight:
                                          FontWeight.w600,
                                        ),
                                      ),
                                      subtitle: Text(email),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }}