import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/subscription_admin_helper.dart';
import 'bk_company_details_page.dart';

class BkCompaniesPage extends StatelessWidget {
  const BkCompaniesPage({super.key});

  Color _statusColor(String status) {
    switch (status) {
      case "active":
        return Colors.green;
      case "blocked":
        return Colors.red;
      case "standby":
        return Colors.orange;
      default:
        return Colors.orange; // pending
    }
  }

  @override
  Widget build(BuildContext context) {
    final stream =
    FirebaseFirestore.instance.collection('companies').snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              "Nessuna azienda disponibile",
              style: TextStyle(color: Colors.black54),
            ),
          );
        }

        final companies = snapshot.data!.docs;

        return ListView.builder(
          itemCount: companies.length,
          itemBuilder: (context, index) {
            final data =
            companies[index].data() as Map<String, dynamic>;
            final companyId = companies[index].id;

            final companyName =
                data['companyName'] ?? 'Senza nome';
            final email =
                data['email'] ?? 'Nessuna email';

            final fallbackStatus =
                data['status'] ?? 'pending';

            return StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(companyId)
                  .snapshots(),
              builder: (context, userSnapshot) {
                String status = fallbackStatus;

                if (userSnapshot.hasData &&
                    userSnapshot.data!.exists) {
                  final userData =
                  userSnapshot.data!.data()
                  as Map<String, dynamic>?;
                  if (userData != null &&
                      userData['status'] != null) {
                    status = userData['status'];
                  }
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 10),
                  child: Card(
                    elevation: 1.5,
                    color: const Color(0xFFF5F5F5),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(18),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                          20, 20, 20, 18),
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          // HEADER
                          Row(
                            children: [
                              Icon(
                                Icons.circle,
                                color:
                                _statusColor(status),
                                size: 12,
                              ),
                              const SizedBox(width: 10),
                              const Icon(
                                Icons.business_outlined,
                                color:
                                Colors.blueGrey,
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  companyName,
                                  style:
                                  const TextStyle(
                                    fontSize: 18,
                                    fontWeight:
                                    FontWeight.w700,
                                    color:
                                    Colors.black,
                                  ),
                                  maxLines: 1,
                                  overflow:
                                  TextOverflow
                                      .ellipsis,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          Text(
                            email,
                            style: TextStyle(
                              color:
                              Colors.grey.shade700,
                              fontSize: 14,
                            ),
                          ),

                          const SizedBox(height: 12),
                          SubscriptionCardSummary(
                            info: SubscriptionAdminHelper.fromCompanyMap(data),
                          ),

                          const SizedBox(height: 18),

                          Align(
                            alignment:
                            Alignment.centerRight,
                            child: ElevatedButton(
                              style:
                              ElevatedButton
                                  .styleFrom(
                                backgroundColor:
                                const Color(
                                    0xFF1565C0),
                                foregroundColor:
                                Colors.white,
                                padding:
                                const EdgeInsets
                                    .symmetric(
                                    horizontal:
                                    20,
                                    vertical:
                                    10),
                                shape:
                                const StadiumBorder(),
                                elevation: 0,
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        BkCompanyDetailsPage(
                                          companyId:
                                          companyId,
                                        ),
                                  ),
                                );
                              },
                              child:
                              const Text("Dettagli"),
                            ),
                          ),
                        ],
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
  }
}
