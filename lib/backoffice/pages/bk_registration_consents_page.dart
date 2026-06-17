import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'bk_job_rules_detail_page.dart';

class BkRegistrationConsentsPage extends StatefulWidget {
  const BkRegistrationConsentsPage({super.key});

  @override
  State<BkRegistrationConsentsPage> createState() =>
      _BkRegistrationConsentsPageState();
}

class _BkRegistrationConsentsPageState extends State<BkRegistrationConsentsPage> {
  static const _docId = 'registration_consents';

  final TextEditingController _controller = TextEditingController();

  bool _loading = true;
  String _version = '1.0.0';

  Future<void> _loadConsents() async {
    final doc = await FirebaseFirestore.instance
        .collection('settings')
        .doc(_docId)
        .get();

    if (doc.exists) {
      final data = doc.data()!;
      _controller.text = data['text'] ?? '';
      _version = (data['version'] ?? '1.0.0').toString();
    }

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _saveConsents() async {
    final versionController = TextEditingController();

    final newVersion = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFF5F5F5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Nuova versione consensi'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Versione attuale: $_version'),
              const SizedBox(height: 10),
              TextField(
                controller: versionController,
                decoration: const InputDecoration(
                  labelText: 'Nuova versione (es. 1.0.1)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annulla'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, versionController.text.trim());
              },
              child: const Text('Salva'),
            ),
          ],
        );
      },
    );

    if (newVersion == null || newVersion.isEmpty) return;

    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();

    batch.set(
      firestore.collection('settings').doc(_docId).collection('versions').doc(newVersion),
      {
        'text': _controller.text,
        'version': newVersion,
        'createdAt': FieldValue.serverTimestamp(),
      },
    );

    batch.set(
      firestore.collection('settings').doc(_docId),
      {
        'text': _controller.text,
        'version': newVersion,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );

    await batch.commit();

    setState(() => _version = newVersion);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Consensi registrazione aggiornati')),
    );
  }

  void _openEditableDetails(String title) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BkJobRulesDetailPage(
          title: title,
          controller: _controller,
          version: _version,
          readOnly: false,
          onSave: _saveConsents,
        ),
      ),
    );

    if (!mounted) return;
    await _loadConsents();
  }

  void _openHistoryDetails(String title, String text, String version) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BkJobRulesDetailPage(
          title: title,
          controller: TextEditingController(text: text),
          version: version,
          readOnly: true,
          onSave: () async {},
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadConsents();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Consensi registrazione',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          _PreviewCard(
            title: 'Privacy e condizioni di registrazione',
            version: _version,
            description:
                'Documento unico che utenti, aziende e collaboratori devono '
                'accettare in registrazione e ad ogni accesso quando la versione cambia.',
            onOpen: () => _openEditableDetails('Consensi registrazione'),
          ),
          const SizedBox(height: 30),
          const Text(
            'Storico versioni',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('settings')
                  .doc(_docId)
                  .collection('versions')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const CircularProgressIndicator();
                }

                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const Text('Nessuna versione salvata');
                }

                return ListView(
                  children: docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final text = (data['text'] ?? '').toString();
                    final version = (data['version'] ?? '').toString();
                    final ts = data['createdAt'] as Timestamp?;
                    final date = ts != null
                        ? DateFormat('dd/MM/yyyy  HH:mm').format(ts.toDate())
                        : '—';

                    return Card(
                      color: const Color(0xFFF5F5F5),
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: ListTile(
                        title: Text('Versione $version'),
                        subtitle: Text(
                          '$date\n${text.length > 180 ? '${text.substring(0, 180)}...' : text}',
                        ),
                        trailing: TextButton(
                          onPressed: () => _openHistoryDetails(
                            'Versione $version',
                            text,
                            version,
                          ),
                          child: const Text('Apri dettagli'),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  final String title;
  final String version;
  final String description;
  final VoidCallback onOpen;

  const _PreviewCard({
    required this.title,
    required this.version,
    required this.description,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFF5F5F5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text('Versione: $version'),
            const SizedBox(height: 10),
            Text(description),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton(
                onPressed: onOpen,
                child: const Text('Apri dettagli'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
