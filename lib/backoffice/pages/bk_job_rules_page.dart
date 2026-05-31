import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'bk_job_rules_detail_page.dart';

class BkJobRulesPage extends StatefulWidget {
  const BkJobRulesPage({super.key});

  @override
  State<BkJobRulesPage> createState() => _BkJobRulesPageState();
}

class _BkJobRulesPageState extends State<BkJobRulesPage> {

  final TextEditingController _controller = TextEditingController();

  bool _loading = true;
  String _version = "1.0";

  Future<void> _loadRules() async {

    final firestore = FirebaseFirestore.instance;

    final doc = await firestore
        .collection('settings')
        .doc('job_offer_rules')
        .get();

    if (doc.exists) {
      final data = doc.data()!;

      _controller.text = data['text'] ?? '';
      _version = (data['version'] ?? '1.0').toString();
    }

    setState(() {
      _loading = false;
    });
  }

  /// --------------------------------------------------
  /// SAVE RULES
  /// --------------------------------------------------

  Future<void> _saveRules() async {

    final controller = TextEditingController();

    final newVersion = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFF5F5F5), // ✅ FIX GRIGIO
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text("Nuova versione regolamento"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              Text("Versione attuale: $_version"),

              const SizedBox(height: 10),

              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: "Nuova versione (es. 2.1)",
                ),
              ),
            ],
          ),
          actions: [

            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Annulla"),
            ),

            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, controller.text.trim());
              },
              child: const Text("Salva"),
            ),
          ],
        );
      },
    );

    if (newVersion == null || newVersion.isEmpty) return;

    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();

    final historyRef = firestore
        .collection('settings')
        .doc('job_offer_rules')
        .collection('versions')
        .doc(newVersion);

    batch.set(historyRef, {
      'text': _controller.text,
      'version': newVersion,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final currentRef = firestore
        .collection('settings')
        .doc('job_offer_rules');

    batch.set(currentRef, {
      'text': _controller.text,
      'version': newVersion,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    setState(() {
      _version = newVersion;
    });

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Regolamento aggiornato')),
    );
  }

  /// --------------------------------------------------
  /// NAVIGATION DETTAGLI
  /// --------------------------------------------------

  void _openEditableDetails(String title) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BkJobRulesDetailPage(
          title: title,
          controller: _controller,
          version: _version,
          readOnly: false,
          onSave: _saveRules,
        ),
      ),
    );

    if (!mounted) return;
    await _loadRules();
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
    _loadRules();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// --------------------------------------------------
  /// BUILD
  /// --------------------------------------------------

  @override
  Widget build(BuildContext context) {

    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          const Text(
            'Regole pubblicazione offerte',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 20),

          _PreviewCard(
            title: "Regole pubblicazione offerte",
            version: _version,
            description:
            "Regolamento che le aziende devono accettare prima di pubblicare un'offerta di lavoro.",
            onOpen: () => _openEditableDetails("Regole pubblicazione offerte"),
          ),

          const SizedBox(height: 30),

          const Text(
            "Storico versioni regolamento",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 10),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('settings')
                  .doc('job_offer_rules')
                  .collection('versions')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {

                if (!snapshot.hasData) {
                  return const CircularProgressIndicator();
                }

                final docs = snapshot.data!.docs;

                if (docs.isEmpty) {
                  return const Text("Nessuna versione salvata");
                }

                return ListView(
                  children: docs.map((doc) {

                    final data = doc.data() as Map<String, dynamic>;
                    final text = (data['text'] ?? '').toString();
                    final version = (data['version'] ?? '').toString();

                    final ts = data['createdAt'] as Timestamp?;
                    final date = ts != null
                        ? DateFormat("dd/MM/yyyy  HH:mm")
                        .format(ts.toDate())
                        : "—";

                    return Card(
                      color: const Color(0xFFF5F5F5),
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: ListTile(
                        title: Text("Versione $version"),
                        subtitle: Text(
                          text.length > 180
                              ? "${text.substring(0,180)}..."
                              : text,
                        ),
                        trailing: TextButton(
                          onPressed: () =>
                              _openHistoryDetails("Versione $version", text, version),
                          child: const Text("Apri dettagli"),
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            Text("Versione: $version"),

            const SizedBox(height: 10),

            Text(description),

            const SizedBox(height: 20),

            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton(
                onPressed: onOpen,
                child: const Text("Apri dettagli"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}