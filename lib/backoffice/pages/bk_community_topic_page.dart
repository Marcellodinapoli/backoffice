import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../utils/bk_community_read_state.dart';
import '../widgets/bk_impaginazione_secondaria.dart';

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

class _CommunityTopicPageState extends State<CommunityTopicPage> {
  String? replyingTo;
  final TextEditingController _msgCtrl = TextEditingController();
  final user = FirebaseAuth.instance.currentUser;

  final Set<String> _seenMessages = {};
  int _lastSeen = 0;
  bool _readStateReady = false;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadLastSeen();
    _checkAdmin();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkAdmin() async {
    final token = await user?.getIdTokenResult(true);
    if (!mounted) return;
    setState(() => _isAdmin = token?.claims?['admin'] == true);
  }

  void _loadLastSeen() {
    final now = DateTime.now().millisecondsSinceEpoch;
    _lastSeen = BkCommunityReadState.getTopicLastSeenMs(widget.topicId);

    if (_lastSeen == 0) {
      BkCommunityReadState.ensureTopicInitialized(widget.topicId, now);
      _lastSeen = now;
    } else {
      BkCommunityReadState.setTopicLastSeenMs(widget.topicId, now);
    }

    setState(() => _readStateReady = true);
  }

  void _saveSeenMessage(String id) {
    _seenMessages.add(id);
  }

  Future<String> _resolveUserName() async {
    if (user == null) return 'Utente anonimo';
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        return data['name']?.toString().trim().isNotEmpty == true
            ? data['name'].toString()
            : data['firstName']?.toString() ??
                user?.email ??
                'Utente anonimo';
      }
    } catch (_) {}
    return user?.email ?? 'Utente anonimo';
  }

  Future<void> _sendMessage() async {
    if (_msgCtrl.text.trim().isEmpty) return;

    final text = _msgCtrl.text.trim();
    _msgCtrl.clear();
    final userName = await _resolveUserName();

    await FirebaseFirestore.instance
        .collection('community')
        .doc(widget.topicId)
        .collection('messages')
        .add({
      'text': text,
      'userId': user?.uid,
      'userName': userName,
      'replyTo': replyingTo,
      'timestamp': FieldValue.serverTimestamp(),
    });

    if (mounted) setState(() => replyingTo = null);
  }

  void _editMessage(String msgId, String currentText) {
    final ctrl = TextEditingController(text: currentText);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Modifica messaggio'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Testo'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('community')
                  .doc(widget.topicId)
                  .collection('messages')
                  .doc(msgId)
                  .update({'text': ctrl.text.trim()});
              if (!context.mounted) return;
              Navigator.pop(context);
            },
            child: const Text('Salva'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteMessage(String msgId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Elimina messaggio'),
        content: const Text('Vuoi davvero eliminare questo messaggio?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('community')
          .doc(widget.topicId)
          .collection('messages')
          .doc(msgId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Messaggio eliminato')),
        );
      }
    }
  }

  bool _hasReplies(
    String messageUserName,
    List<QueryDocumentSnapshot> allMessages,
  ) {
    for (final msg in allMessages) {
      final data = msg.data() as Map<String, dynamic>;
      if (data['replyTo'] == messageUserName) return true;
    }
    return false;
  }

  Widget _buildMessageTile(
    Map<String, dynamic> data,
    String msgId,
    bool isReply,
    bool isMobile,
    bool canEditOrDelete,
  ) {
    final userName = data['userName'] ?? 'Anonimo';
    final text = data['text'] ?? '';
    final replyTo = data['replyTo'];
    final userId = data['userId'];
    final ts = data['timestamp'] as Timestamp?;
    final time = ts?.toDate();
    final isMine = userId == user?.uid;

    final isNew = _readStateReady &&
        !_seenMessages.contains(msgId) &&
        !isMine &&
        (ts != null && ts.millisecondsSinceEpoch > _lastSeen);

    if (isNew) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _saveSeenMessage(msgId);
      });
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isReply ? Colors.grey.shade100 : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300, width: 0.8),
      ),
      child: Stack(
        children: [
          ListTile(
            dense: isMobile,
            title: Text(
              userName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (replyTo != null)
                  Text(
                    '↪ Risposta a $replyTo',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                Text(text),
                if (time != null)
                  Text(
                    '${time.day}/${time.month}/${time.year} '
                    '${time.hour.toString().padLeft(2, '0')}:'
                    '${time.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
              ],
            ),
            trailing: isMine || _isAdmin
                ? (isMobile
                    ? PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Colors.grey),
                        onSelected: (value) {
                          if (value == 'reply') {
                            setState(() => replyingTo = userName);
                          }
                          if (value == 'edit' && canEditOrDelete) {
                            _editMessage(msgId, text);
                          }
                          if (value == 'delete' && canEditOrDelete) {
                            _deleteMessage(msgId);
                          }
                          if ((value == 'edit' || value == 'delete') &&
                              !canEditOrDelete) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Non puoi modificare o eliminare questo messaggio: ha già risposte.',
                                ),
                              ),
                            );
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'reply',
                            child: Text('Rispondi'),
                          ),
                          PopupMenuItem(
                            value: 'edit',
                            enabled: canEditOrDelete,
                            child: const Text('Modifica'),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            enabled: canEditOrDelete,
                            child: const Text('Elimina'),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.reply,
                                size: 20, color: Colors.grey),
                            onPressed: () =>
                                setState(() => replyingTo = userName),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit' && canEditOrDelete) {
                                _editMessage(msgId, text);
                              }
                              if (value == 'delete' && canEditOrDelete) {
                                _deleteMessage(msgId);
                              }
                              if ((value == 'edit' || value == 'delete') &&
                                  !canEditOrDelete) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Non puoi modificare o eliminare questo messaggio: ha già risposte.',
                                    ),
                                  ),
                                );
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'edit',
                                enabled: canEditOrDelete,
                                child: const Text('Modifica'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                enabled: canEditOrDelete,
                                child: const Text('Elimina'),
                              ),
                            ],
                          ),
                        ],
                      ))
                : IconButton(
                    icon: const Icon(Icons.reply, size: 20, color: Colors.grey),
                    onPressed: () => setState(() => replyingTo = userName),
                  ),
          ),
          if (isNew)
            Positioned(
              top: 6,
              right: 8,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'NEW',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildComposer(bool isMobile) {
    final replyBanner = replyingTo == null
        ? null
        : Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Rispondendo a $replyingTo',
                    style: const TextStyle(fontStyle: FontStyle.italic),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => replyingTo = null),
                  child: const Icon(Icons.close, size: 18),
                ),
              ],
            ),
          );

    final field = TextField(
      controller: _msgCtrl,
      minLines: 1,
      maxLines: 4,
      textInputAction: TextInputAction.send,
      onSubmitted: (_) => _sendMessage(),
      decoration: const InputDecoration(
        hintText: 'Scrivi un messaggio...',
        border: OutlineInputBorder(),
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (replyBanner != null) replyBanner,
        if (isMobile) ...[
          field,
          const SizedBox(height: 8),
          ElevatedButton.icon(
            icon: const Icon(Icons.send),
            label: const Text('Invia'),
            onPressed: _sendMessage,
          ),
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: field),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.send),
                label: const Text('Invia'),
                onPressed: _sendMessage,
              ),
            ],
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;

    return ImpaginazioneSecondariaBk(
      pageTitle: 'Discussione',
      body: Card(
        elevation: 3,
        color: const Color(0xFFF5F5F5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            isMobile ? 12 : 20,
            isMobile ? 12 : 20,
            isMobile ? 12 : 20,
            12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Argomento: ${widget.topicTitle}',
                style: TextStyle(
                  fontSize: isMobile ? 16 : 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('community')
                      .doc(widget.topicId)
                      .collection('messages')
                      .orderBy('timestamp')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Text('Nessun messaggio ancora'),
                      );
                    }

                    final messages = snapshot.data!.docs;
                    final mainMessages = messages
                        .where((m) =>
                            (m.data() as Map<String, dynamic>)['replyTo'] ==
                            null)
                        .toList();
                    final replies = messages
                        .where((m) =>
                            (m.data() as Map<String, dynamic>)['replyTo'] !=
                            null)
                        .toList();

                    return ListView(
                      padding: EdgeInsets.zero,
                      children: mainMessages.map((msg) {
                        final data = msg.data() as Map<String, dynamic>;
                        final children = replies.where((r) {
                          final rData = r.data() as Map<String, dynamic>;
                          return rData['replyTo'] == data['userName'];
                        }).toList();

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildMessageTile(
                              data,
                              msg.id,
                              false,
                              isMobile,
                              _isAdmin ||
                                  !_hasReplies(data['userName'], messages),
                            ),
                            ...children.map((r) {
                              final rData = r.data() as Map<String, dynamic>;
                              return Padding(
                                padding: const EdgeInsets.only(left: 24),
                                child: _buildMessageTile(
                                  rData,
                                  r.id,
                                  true,
                                  isMobile,
                                  _isAdmin ||
                                      !_hasReplies(rData['userName'], messages),
                                ),
                              );
                            }),
                          ],
                        );
                      }).toList(),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              _buildComposer(isMobile),
            ],
          ),
        ),
      ),
    );
  }
}
