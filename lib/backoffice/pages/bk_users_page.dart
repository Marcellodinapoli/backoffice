import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/user_account_status.dart';
import '../utils/subscription_admin_helper.dart';
import 'bk_user_details_page.dart';

class BkUsersPage extends StatefulWidget {
  const BkUsersPage({super.key});

  @override
  State<BkUsersPage> createState() => _BkUsersPageState();
}

class _BkUsersPageState extends State<BkUsersPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          labelColor: Colors.blue,
          unselectedLabelColor: Colors.black54,
          tabs: const [
            Tab(text: "Generici"),
            Tab(text: "Work"),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _UserList(userType: "public"),
              _UserList(userType: "work"),
            ],
          ),
        ),
      ],
    );
  }
}

class _UserList extends StatefulWidget {
  final String userType;
  const _UserList({required this.userType});

  @override
  State<_UserList> createState() => _UserListState();
}

class _UserListState extends State<_UserList> {
  final Map<String, Future<SubscriptionCardInfo>> _usageFutures = {};
  final Map<String, Future<DocumentSnapshot?>> _companyFutures = {};

  Future<SubscriptionCardInfo> _loadPublicUsage(
    String userId,
    Map<String, dynamic> user,
  ) {
    final fallback = SubscriptionAdminHelper.fromPublicUserMap(user);
    return _usageFutures.putIfAbsent(
      userId,
      () => SubscriptionAdminHelper.loadPublicUsage(userId).catchError(
        (_) => fallback,
      ),
    );
  }

  Future<DocumentSnapshot?> _loadCompany(String companyId) {
    return _companyFutures.putIfAbsent(
      companyId,
      () => FirebaseFirestore.instance.collection('companies').doc(companyId).get(),
    );
  }

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

  String _formatDate(dynamic ts) => UserAccountStatus.formatDateTime(ts);

  String _roleLabel(String? role) {
    switch (role) {
      case "supervisor":
        return "Supervisor";
      case "collaborator":
        return "Collaboratore";
      default:
        return "N/D";
    }
  }

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('users')
        .where('type', isEqualTo: widget.userType)
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              "Nessun utente disponibile",
              style: TextStyle(color: Colors.black54),
            ),
          );
        }

        final users = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 24),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index].data() as Map<String, dynamic>;
            final userId = users[index].id;

            final name = user['name'] ?? 'Senza nome';
            final email = user['email'] ?? 'Nessuna email';
            final rawStatus =
                user['status'] ?? UserAccountStatus.defaultRawStatus(widget.userType);
            final status = UserAccountStatus.displayStatus(
              rawStatus,
              type: widget.userType,
            );
            final workRole = user['workRole'];
            final companyId = user['companyId'];
            final lastLoginAt = user['lastLoginAt'];

            return Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Card(
                elevation: 1.5,
                color: const Color(0xFFF5F5F5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                            Icons.person_outline,
                            color: Colors.blueGrey,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              name,
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
                      const SizedBox(height: 10),
                      Text(
                        email,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 14,
                        ),
                      ),
                      if (widget.userType == 'public') ...[
                        const SizedBox(height: 12),
                        FutureBuilder<SubscriptionCardInfo>(
                          future: _loadPublicUsage(userId, user),
                          builder: (context, subSnap) {
                            final info = subSnap.data ??
                                SubscriptionAdminHelper.fromPublicUserMap(user);
                            return SubscriptionCardSummary(info: info);
                          },
                        ),
                      ],
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: widget.userType == "work"
                            ? FutureBuilder<DocumentSnapshot>(
                                future: companyId != null
                                    ? _loadCompany(companyId)
                                    : null,
                                builder: (context, companySnap) {
                                  String companyName = "N/D";

                                  if (companySnap.hasData &&
                                      companySnap.data!.exists) {
                                    final companyData = companySnap.data!.data()
                                        as Map<String, dynamic>;
                                    companyName =
                                        companyData['name'] ?? "N/D";
                                  }

                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Ruolo: ${_roleLabel(workRole)}",
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        "Azienda: $companyName",
                                        style: const TextStyle(
                                          fontSize: 13,
                                        ),
                                      ),
                                      Text(
                                        "Ultimo accesso: ${_formatDate(lastLoginAt)}",
                                        style: const TextStyle(
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              )
                            : Text(
                                "Ultimo accesso: ${_formatDate(lastLoginAt)}",
                                style: const TextStyle(fontSize: 13),
                              ),
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1565C0),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 10),
                            shape: const StadiumBorder(),
                            elevation: 0,
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    BkUserDetailsPage(userId: userId),
                              ),
                            );
                          },
                          child: const Text("Accedi"),
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
  }
}
