// ================================================================
// IMPORT
// ================================================================
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ================================================================
// PAGE ROOT
// ================================================================
class BkSupportPage extends StatefulWidget {
  const BkSupportPage({super.key});

  @override
  State<BkSupportPage> createState() => _BkSupportPageState();
}

// ================================================================
// STATE
// ================================================================
class _BkSupportPageState extends State<BkSupportPage> {
  final user = FirebaseAuth.instance.currentUser;

  Set<String> _seenTickets = {};
  int _lastSeen = 0;

  // ================================================================
  // LIFECYCLE
  // ================================================================
  @override
  void initState() {
    super.initState();
    _loadLastSeen();
    _loadSeenTickets();
  }

  // ================================================================
  // LOCAL STORAGE
  // ================================================================
  void _loadLastSeen() {
    final stored = html.window.localStorage['lastSeenSupport'];
    if (stored != null) {
      _lastSeen = int.tryParse(stored) ?? 0;
    }
    html.window.localStorage['lastSeenSupport'] =
        DateTime.now().millisecondsSinceEpoch.toString();
  }

  void _loadSeenTickets() {
    final stored = html.window.localStorage['seenTickets'];
    if (stored != null && stored.isNotEmpty) {
      _seenTickets = stored.split(',').toSet();
    }
  }

  void _saveSeenTicket(String id) {
    _seenTickets.add(id);
    html.window.localStorage['seenTickets'] =
        _seenTickets.join(',');
  }

// ================================================================
// BUILD
// ================================================================
  @override
  Widget build(BuildContext context) {
    final isMobile =
        MediaQuery.of(context).size.width < 600;

    return FutureBuilder<IdTokenResult>(
      future: user?.getIdTokenResult(true),
      builder: (context, tokenSnap) {

        if (tokenSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final isAdmin =
            tokenSnap.data?.claims?['admin'] == true;

        final stream = isAdmin
            ? FirebaseFirestore.instance
            .collection('support')
            .snapshots()
            : FirebaseFirestore.instance
            .collection('support')
            .where(
          'userId',
          isEqualTo: user?.uid,
        )
            .snapshots();

        return Scaffold(
          backgroundColor: Colors.white,
          body: Padding(
            padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12 : 24),
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),

                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: stream,
                    builder: (context, snapshot) {

                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }

                      if (!snapshot.hasData ||
                          snapshot.data!.docs.isEmpty) {
                        return const Center(
                          child: Text(
                            "Nessun ticket ancora inviato",
                          ),
                        );
                      }

                      final tickets =
                          snapshot.data!.docs;

                      return ListView.builder(
                        itemCount: tickets.length,
                        itemBuilder: (context, index) {

                          final ticket =
                          tickets[index];
                          final ticketId =
                              ticket.id;

                          final subject =
                              ticket['subject'] ?? '';

                          final status =
                              ticket['status'] ?? 'open';

                          final createdAt =
                          (ticket['createdAt']
                          as Timestamp?)
                              ?.toDate()
                              .toLocal();

                          final replyCtrl =
                          TextEditingController();

                          return FutureBuilder<DocumentSnapshot>(
                            future: FirebaseFirestore
                                .instance
                                .collection('users')
                                .doc(ticket['userId'])
                                .get(),
                            builder:
                                (context, userSnap) {

                              String firstName = "";
                              String lastName = "";
                              String userEmail =
                                  ticket['userEmail'] ?? "";

                              if (userSnap.hasData &&
                                  userSnap.data!.exists) {
                                final data =
                                userSnap.data!.data()
                                as Map<String, dynamic>;

                                firstName =
                                    data['firstName'] ??
                                        data['name'] ??
                                        "";

                                lastName =
                                    data['lastName'] ??
                                        "";

                                userEmail =
                                    data['email'] ??
                                        userEmail;
                              }

                              return Container(
                                margin:
                                const EdgeInsets.symmetric(
                                    vertical: 8),
                                child: Align(
                                  alignment:
                                  Alignment.topCenter,
                                  child:
                                  ConstrainedBox(
                                    constraints:
                                    const BoxConstraints(
                                        maxWidth:
                                        1300),
                                    child: Card(
                                      color: const Color(
                                          0xFFF5F5F5),
                                      shape:
                                      RoundedRectangleBorder(
                                        borderRadius:
                                        BorderRadius
                                            .circular(
                                            12),
                                      ),
                                      child: Padding(
                                        padding:
                                        const EdgeInsets
                                            .all(12),
                                        child: Column(
                                          crossAxisAlignment:
                                          CrossAxisAlignment
                                              .start,
                                          children: [

                                            // HEADER
                                            Row(
                                              children: [
                                                Expanded(
                                                  child:
                                                  Text(
                                                    subject,
                                                    style:
                                                    TextStyle(
                                                      fontSize:
                                                      isMobile
                                                          ? 14
                                                          : 16,
                                                      fontWeight:
                                                      FontWeight
                                                          .bold,
                                                    ),
                                                  ),
                                                ),
                                                Container(
                                                  padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal:
                                                      8,
                                                      vertical:
                                                      4),
                                                  decoration:
                                                  BoxDecoration(
                                                    color: status ==
                                                        'closed'
                                                        ? Colors.grey
                                                        : Colors.green,
                                                    borderRadius:
                                                    BorderRadius.circular(
                                                        8),
                                                  ),
                                                  child: Text(
                                                    status ==
                                                        'closed'
                                                        ? 'CHIUSO'
                                                        : 'APERTO',
                                                    style:
                                                    const TextStyle(
                                                      color:
                                                      Colors
                                                          .white,
                                                      fontSize:
                                                      12,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),

                                            const SizedBox(
                                                height: 4),

                                            Text(
                                              "Da: $lastName $firstName — $userEmail",
                                              style:
                                              const TextStyle(
                                                fontSize:
                                                13,
                                                fontWeight:
                                                FontWeight
                                                    .w500,
                                                color: Colors
                                                    .black87,
                                              ),
                                            ),

                                            if (createdAt !=
                                                null)
                                              Text(
                                                "Inviato il ${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year}",
                                                style:
                                                const TextStyle(
                                                  fontSize:
                                                  12,
                                                  color: Colors
                                                      .black54,
                                                ),
                                              ),

                                            const Divider(),

                                            // MESSAGGI
                                            StreamBuilder<QuerySnapshot>(
                                              stream: ticket
                                                  .reference
                                                  .collection(
                                                  'messages')
                                                  .orderBy(
                                                  'timestamp')
                                                  .snapshots(),
                                              builder: (context,
                                                  msgSnap) {

                                                if (!msgSnap
                                                    .hasData) {
                                                  return const SizedBox();
                                                }

                                                final msgs =
                                                    msgSnap
                                                        .data!
                                                        .docs;

                                                return Column(
                                                  children:
                                                  msgs.map(
                                                          (m) {
                                                        final data =
                                                        m.data()
                                                        as Map<String,
                                                            dynamic>;

                                                        final sender =
                                                        data['sender'];

                                                        final text =
                                                            data['text'] ??
                                                                '';

                                                        final isUser =
                                                            sender ==
                                                                'user';

                                                        return Container(
                                                          margin:
                                                          const EdgeInsets.symmetric(
                                                              vertical:
                                                              4),
                                                          padding:
                                                          const EdgeInsets.all(
                                                              8),
                                                          decoration:
                                                          BoxDecoration(
                                                            color: isUser
                                                                ? Colors.white
                                                                : Colors.blue.shade50,
                                                            borderRadius:
                                                            BorderRadius.circular(
                                                                8),
                                                            border:
                                                            Border.all(
                                                              color: Colors.grey
                                                                  .shade300,
                                                            ),
                                                          ),
                                                          child: Row(
                                                            crossAxisAlignment:
                                                            CrossAxisAlignment.start,
                                                            children: [
                                                              Icon(
                                                                isUser
                                                                    ? Icons.person_outline
                                                                    : Icons.support_agent,
                                                                size:
                                                                18,
                                                                color: isUser
                                                                    ? Colors.grey
                                                                    : Colors.blue,
                                                              ),
                                                              const SizedBox(
                                                                  width:
                                                                  8),
                                                              Expanded(
                                                                child:
                                                                Column(
                                                                  crossAxisAlignment:
                                                                  CrossAxisAlignment.start,
                                                                  children: [
                                                                    Text(
                                                                      isUser
                                                                          ? "Utente"
                                                                          : "Assistenza",
                                                                      style:
                                                                      TextStyle(
                                                                        fontWeight:
                                                                        FontWeight.bold,
                                                                        color: isUser
                                                                            ? Colors.black87
                                                                            : Colors.blue,
                                                                      ),
                                                                    ),
                                                                    Text(
                                                                        text),
                                                                  ],
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        );
                                                      }).toList(),
                                                );
                                              },
                                            ),

                                            if (isAdmin &&
                                                status !=
                                                    'closed') ...[
                                              const SizedBox(
                                                  height: 12),

                                              TextField(
                                                controller:
                                                replyCtrl,
                                                decoration:
                                                const InputDecoration(
                                                  labelText:
                                                  "Scrivi risposta",
                                                  border:
                                                  OutlineInputBorder(),
                                                ),
                                              ),

                                              const SizedBox(
                                                  height: 8),

                                              Row(
                                                children: [
                                                  ElevatedButton(
                                                    onPressed:
                                                        () async {
                                                      if (replyCtrl
                                                          .text
                                                          .trim()
                                                          .isEmpty) return;

                                                      await ticket.reference
                                                          .collection(
                                                          'messages')
                                                          .add({
                                                        'text':
                                                        replyCtrl.text
                                                            .trim(),
                                                        'sender':
                                                        'admin',
                                                        'timestamp':
                                                        FieldValue.serverTimestamp(),
                                                      });

                                                      replyCtrl
                                                          .clear();
                                                    },
                                                    child:
                                                    const Text(
                                                        "Rispondi"),
                                                  ),
                                                  const SizedBox(
                                                      width:
                                                      12),
                                                  ElevatedButton(
                                                    style:
                                                    ElevatedButton.styleFrom(
                                                      backgroundColor:
                                                      Colors.red,
                                                    ),
                                                    onPressed:
                                                        () async {
                                                      await ticket
                                                          .reference
                                                          .update({
                                                        'status':
                                                        'closed'
                                                      });
                                                    },
                                                    child:
                                                    const Text(
                                                        "Chiudi ticket"),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ],
                                        ),
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
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}