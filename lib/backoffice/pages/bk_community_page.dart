// ================================================================
// IMPORT
// ================================================================
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../utils/bk_community_read_state.dart';
import 'bk_community_topic_page.dart';


// ================================================================
// PAGE ROOT
// ================================================================
class BkCommunityPage extends StatefulWidget {
  const BkCommunityPage({super.key});

  @override
  State<BkCommunityPage> createState() => _BkCommunityPageState();
}


// ================================================================
// STATE
// ================================================================
class _BkCommunityPageState extends State<BkCommunityPage> {

  final user = FirebaseAuth.instance.currentUser;

  bool _isAdmin = false;
  String _userName = 'Utente';
  Map<String, int> _topicLastSeen = {};
  bool _readStateReady = false;

  @override
  void initState() {
    super.initState();
    _topicLastSeen = BkCommunityReadState.getTopicsLastSeen();
    _readStateReady = true;
    _checkAdmin();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();
      if (!mounted || !doc.exists) return;
      setState(() {
        _userName = doc.data()?['name']?.toString().trim().isNotEmpty == true
            ? doc.data()!['name'].toString()
            : 'Utente';
      });
    } catch (_) {}
  }

  Future<void> _checkAdmin() async {
    final token = await user?.getIdTokenResult(true);
    if (!mounted) return;
    setState(() {
      _isAdmin = token?.claims?['admin'] == true;
    });
  }

  bool get isAdmin => _isAdmin;


  // ================================================================
  // ACTIONS
  // ================================================================

  /// 🔹 CREA NUOVO ARGOMENTO
  void _openNewTopicDialog() {

    final titleCtrl = TextEditingController();
    final messageCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text("Nuovo argomento"),
          content: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: "Titolo argomento",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: messageCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: "Messaggio iniziale",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Annulla"),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.send),
              label: const Text("Pubblica"),
              onPressed: () async {

                final title = titleCtrl.text.trim();
                final message = messageCtrl.text.trim();
                if (title.isEmpty || message.isEmpty) return;

                try {

                  final topicsRef =
                  FirebaseFirestore.instance.collection('community');
                  final topicDoc = topicsRef.doc();

                  await topicDoc.set({
                    'title': title,
                    'createdBy': _userName,
                    'userId': user?.uid,
                    'createdAt': FieldValue.serverTimestamp(),
                    'status': isAdmin ? 'approved' : 'pending',
                  });

                  await topicDoc.collection('messages').add({
                    'text': message,
                    'userId': user?.uid,
                    'userName': _userName,
                    'timestamp': FieldValue.serverTimestamp(),
                  });

                  if (!context.mounted) return;
                  Navigator.pop(context);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isAdmin
                            ? "✅ Argomento pubblicato"
                            : "✅ Argomento inviato per approvazione",
                      ),
                    ),
                  );

                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content:
                        Text("❌ Errore durante la pubblicazione: $e")),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }


  /// 🔹 MODIFICA TITOLO
  void _editTopic(DocumentSnapshot topic) {

    final ctrl = TextEditingController(text: topic['title'] ?? '');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Modifica titolo"),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: "Nuovo titolo",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Annulla"),
          ),
          ElevatedButton(
            onPressed: () async {
              await topic.reference.update({'title': ctrl.text.trim()});
              if (!mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("✅ Titolo aggiornato")),
              );
            },
            child: const Text("Salva"),
          ),
        ],
      ),
    );
  }


  /// 🔹 ELIMINA ARGOMENTO
  Future<void> _deleteTopic(DocumentSnapshot topic) async {

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Elimina argomento"),
        content: const Text(
            "Vuoi davvero eliminare questo argomento e tutti i messaggi collegati?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Annulla"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Elimina"),
          ),
        ],
      ),
    );

    if (confirm == true) {

      final messages =
      await topic.reference.collection('messages').get();

      for (var msg in messages.docs) {
        await msg.reference.delete();
      }

      await topic.reference.delete();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("🗑️ Argomento eliminato")),
      );
    }
  }


  /// 🔹 APPROVA / RIFIUTA
  Future<void> _approveTopic(DocumentSnapshot topic, bool approve) async {

    await topic.reference
        .update({'status': approve ? 'approved' : 'rejected'});

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
        Text(approve ? "✅ Argomento approvato" : "🚫 Argomento rifiutato"),
      ),
    );
  }


  /// 🔹 APRE DISCUSSIONE
  Future<void> _openTopicMessages(DocumentSnapshot topic) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => CommunityTopicPage(
          topicId: topic.id,
          topicTitle: topic['title'] ?? 'Discussione',
        ),
      ),
    );

    final now = DateTime.now().millisecondsSinceEpoch;
    BkCommunityReadState.setTopicLastSeenMs(topic.id, now);
    if (mounted) {
      setState(() => _topicLastSeen[topic.id] = now);
    }
  }


  // ================================================================
  // UI HELPERS
  // ================================================================

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String _statusText(String status) {
    switch (status) {
      case 'approved':
        return "Approvato";
      case 'rejected':
        return "Rifiutato";
      default:
        return "In revisione";
    }
  }


  // ================================================================
  // BUILD
  // ================================================================
  @override
  Widget build(BuildContext context) {

    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text("Nuovo argomento"),
                  onPressed: _openNewTopicDialog,
                ),
              ],
            ),

            const SizedBox(height: 16),

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('community')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {

                  if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData ||
                      snapshot.data!.docs.isEmpty) {
                    return const Center(
                        child: Text("Nessun argomento ancora pubblicato"));
                  }

                  final topics = snapshot.data!.docs.where((topic) {

                    final data =
                    topic.data() as Map<String, dynamic>;

                    final isOwner =
                        data['userId'] == user?.uid;

                    final status =
                        data['status'] ?? 'pending';

                    if (isAdmin) return true;

                    return status == 'approved' || isOwner;

                  }).toList();

                  if (topics.isEmpty) {
                    return const Center(
                        child: Text("Nessun argomento disponibile"));
                  }

                  return ListView.builder(
                    itemCount: topics.length,
                    itemBuilder: (context, index) {

                      final topic = topics[index];
                      final title =
                          topic['title'] ?? 'Argomento senza titolo';
                      final author =
                          topic['createdBy'] ?? 'Sconosciuto';
                      final status =
                          topic['status'] ?? 'pending';
                      final isOwner =
                          topic['userId'] == user?.uid;

                      return Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints:
                          const BoxConstraints(maxWidth: 1300),
                          child: StreamBuilder<QuerySnapshot>(
                            stream: topic.reference
                                .collection('messages')
                                .snapshots(),
                            builder: (context, msgSnap) {
                              final docs = msgSnap.data?.docs ?? [];
                              final lastSeen =
                                  _topicLastSeen[topic.id] ?? 0;
                              final unreadCount = _readStateReady &&
                                      lastSeen > 0
                                  ? docs.where((doc) {
                                      final data =
                                          doc.data() as Map<String, dynamic>;
                                      final ts =
                                          data['timestamp'] as Timestamp?;
                                      final senderId = data['userId'];
                                      return ts != null &&
                                          senderId != user?.uid &&
                                          ts.millisecondsSinceEpoch > lastSeen;
                                    }).length
                                  : 0;

                              return Card(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            color: const Color(0xFFF5F5F5),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                              BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      title,
                                      style: const TextStyle(
                                          fontWeight:
                                          FontWeight.bold),
                                    ),
                                  ),
                                  if (unreadCount > 0)
                                    Container(
                                      margin:
                                          const EdgeInsets.only(right: 8),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '$unreadCount',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  Row(
                                    children: [
                                      Icon(Icons.circle,
                                          color:
                                          _statusColor(status),
                                          size: 10),
                                      const SizedBox(width: 6),
                                      Text(
                                        _statusText(status),
                                        style: TextStyle(
                                          color:
                                          _statusColor(status),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              subtitle: Text(
                                'di $author • ${docs.length} commenti',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [

                                  IconButton(
                                    icon: const Icon(Icons.chat_outlined),
                                    tooltip: "Apri discussione",
                                    onPressed: () =>
                                        _openTopicMessages(topic),
                                  ),

                                  if ((isOwner && status == 'pending') ||
                                      isAdmin) ...[
                                    IconButton(
                                      icon: const Icon(Icons.edit,
                                          color: Colors.blue),
                                      tooltip: "Modifica titolo",
                                      onPressed: () =>
                                          _editTopic(topic),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete,
                                          color: Colors.red),
                                      tooltip: "Elimina argomento",
                                      onPressed: () =>
                                          _deleteTopic(topic),
                                    ),
                                  ],

                                  if (isAdmin &&
                                      status == 'pending') ...[
                                    IconButton(
                                      icon: const Icon(Icons.check_circle,
                                          color: Colors.green),
                                      tooltip: "Approva argomento",
                                      onPressed: () =>
                                          _approveTopic(topic, true),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.cancel,
                                          color: Colors.red),
                                      tooltip: "Rifiuta argomento",
                                      onPressed: () =>
                                          _approveTopic(topic, false),
                                    ),
                                  ],

                                ],
                              ),
                            ),
                          );
                            },
                          ),
                        ),
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
  }
}
