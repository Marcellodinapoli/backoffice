// ================================================================
// IMPORT
// ================================================================
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/bk_local_storage.dart';
import '../widgets/bk_impaginazione_secondaria.dart';

// ================================================================
// PAGE ROOT
// ================================================================
class CommunityTopicPage extends StatefulWidget {
  final String topicId;
  final String topicTitle;

  const CommunityTopicPage({
    super.key,
    required this.topicId,
    required this.topicTitle,
  });

  @override
  State<CommunityTopicPage> createState() => _CommunityTopicPageState();
}

// ================================================================
// STATE
// ================================================================
class _CommunityTopicPageState extends State<CommunityTopicPage> {

  final TextEditingController _msgCtrl = TextEditingController();
  final user = FirebaseAuth.instance.currentUser;

  String? replyingTo;

  Set<String> _seenMessages = {};
  int _lastSeen = 0;

  // ================================================================
  // LIFECYCLE
  // ================================================================
  @override
  void initState() {
    super.initState();
    _loadLastSeen();
    _loadSeenMessages();
  }

  // ================================================================
  // SERVICES / HELPERS (LOCAL STORAGE)
  // ================================================================
  void _loadLastSeen() {
    final stored = bkLocalStorageGet('lastSeen');
    if (stored != null) {
      _lastSeen = int.tryParse(stored) ?? 0;
    }
    bkLocalStorageSet(
      'lastSeen',
      DateTime.now().millisecondsSinceEpoch.toString(),
    );
  }

  void _loadSeenMessages() {
    final stored = bkLocalStorageGet('seenCommunityMessages');
    if (stored != null && stored.isNotEmpty) {
      _seenMessages = stored.split(',').toSet();
    }
  }

  void _saveSeenMessage(String id) {
    _seenMessages.add(id);
    bkLocalStorageSet('seenCommunityMessages', _seenMessages.join(','));
  }

  // ================================================================
  // ACTIONS
  // ================================================================
  Future<void> _sendMessage() async {
    if (_msgCtrl.text.trim().isEmpty) return;

    final text = _msgCtrl.text.trim();
    _msgCtrl.clear();

    await FirebaseFirestore.instance
        .collection('community')
        .doc(widget.topicId)
        .collection('messages')
        .add({
      'text': text,
      'userId': user?.uid,
      'userName': user?.email ?? 'Utente anonimo',
      'replyTo': replyingTo,
      'timestamp': FieldValue.serverTimestamp(),
    });

    setState(() => replyingTo = null);
  }

  // ================================================================
  // UI HELPERS
  // ================================================================
  Widget _buildMessageTile(
      Map<String, dynamic> data,
      String msgId,
      bool isReply,
      bool isMobile) {

    final userName = data['userName'] ?? 'Anonimo';
    final text = data['text'] ?? '';
    final replyTo = data['replyTo'];
    final userId = data['userId'];
    final ts = data['timestamp'] as Timestamp?;
    final time = ts?.toDate();
    final isMine = userId == user?.uid;

    final isNew = !_seenMessages.contains(msgId) &&
        !isMine &&
        (ts != null &&
            ts.millisecondsSinceEpoch > _lastSeen);

    // ✅ FIX LAMPEGGIO: niente scrittura durante build
    if (isNew) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _saveSeenMessage(msgId);
      });
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color:
        isReply ? Colors.grey.shade100 : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: Colors.grey.shade300, width: 0.8),
      ),
      child: ListTile(
        dense: isMobile,
        title: Text(userName,
            style: const TextStyle(
                fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            if (replyTo != null)
              Text("↪ Risposta a $replyTo",
                  style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey)),
            Text(text),
            if (time != null)
              Text(
                "${time.day}/${time.month}/${time.year} "
                    "${time.hour.toString().padLeft(2, '0')}:"
                    "${time.minute.toString().padLeft(2, '0')}",
                style: const TextStyle(
                    fontSize: 11,
                    color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }

  // ================================================================
// BUILD
// ================================================================
  @override
  Widget build(BuildContext context) {

    final isMobile =
        MediaQuery.of(context).size.width < 800;

    return ImpaginazioneSecondariaBk(
      pageTitle: widget.topicTitle,
      body: Card(
        elevation: 3,
        color: const Color(0xFFF5F5F5),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [

              Text(
                widget.topicTitle,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 16),

              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('community')
                      .doc(widget.topicId)
                      .collection('messages')
                      .orderBy('timestamp')
                      .snapshots(),
                  builder: (context, snapshot) {

                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                          child:
                          CircularProgressIndicator());
                    }

                    if (!snapshot.hasData ||
                        snapshot.data!.docs.isEmpty) {
                      return const Center(
                          child: Text(
                              "Nessun messaggio ancora"));
                    }

                    final messages =
                        snapshot.data!.docs;

                    // 🔹 THREAD LOGIC
                    final mainMessages = messages
                        .where((m) =>
                    (m.data() as Map<String, dynamic>)['replyTo'] == null)
                        .toList();

                    final replies = messages
                        .where((m) =>
                    (m.data() as Map<String, dynamic>)['replyTo'] != null)
                        .toList();

                    return ListView(
                      children: mainMessages.map((msg) {
                        final data =
                        msg.data() as Map<String, dynamic>;

                        final children = replies.where((r) {
                          final rData =
                          r.data() as Map<String, dynamic>;
                          return rData['replyTo'] ==
                              data['userName'];
                        }).toList();

                        return Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            _buildMessageTile(
                                data,
                                msg.id,
                                false,
                                isMobile),

                            // 🔹 RISPOSTE RIENTRATE
                            ...children.map((r) {
                              final rData =
                              r.data() as Map<String, dynamic>;
                              return Padding(
                                padding:
                                const EdgeInsets.only(left: 24),
                                child: _buildMessageTile(
                                    rData,
                                    r.id,
                                    true,
                                    isMobile),
                              );
                            }),
                          ],
                        );
                      }).toList(),
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),

              if (replyingTo != null)
                Container(
                  color: Colors.grey.shade200,
                  padding:
                  const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          "Rispondendo a $replyingTo",
                          style: const TextStyle(
                              fontStyle:
                              FontStyle.italic),
                        ),
                      ),
                      GestureDetector(
                        child: const Icon(Icons.close,
                            size: 18),
                        onTap: () =>
                            setState(
                                    () => replyingTo = null),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 12),

              isMobile
                  ? Column(
                crossAxisAlignment:
                CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _msgCtrl,
                    decoration:
                    const InputDecoration(
                      hintText:
                      "Scrivi un messaggio...",
                      border:
                      OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    icon:
                    const Icon(Icons.send),
                    label:
                    const Text("Invia"),
                    onPressed:
                    _sendMessage,
                  ),
                ],
              )
                  : Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgCtrl,
                      decoration:
                      const InputDecoration(
                        hintText:
                        "Scrivi un messaggio...",
                        border:
                        OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon:
                    const Icon(Icons.send),
                    onPressed:
                    _sendMessage,
                  ),
                ],
              ),

            ],
          ),
        ),
      ),
    );
  }}