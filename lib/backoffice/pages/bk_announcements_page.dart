import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BkAnnouncementsPage extends StatefulWidget {
  const BkAnnouncementsPage({Key? key}) : super(key: key);

  @override
  State<BkAnnouncementsPage> createState() => _BkAnnouncementsPageState();
}

class _BkAnnouncementsPageState extends State<BkAnnouncementsPage> {

  // ---------------------------------------------------------------------------
  // CONFIG / COSTANTI
  // ---------------------------------------------------------------------------

  final List<String> _targets = [
    'all',
    'public',
    'work',
    'company',
  ];

  final List<int> _priorities = [1, 2, 3, 4];

// ---------------------------------------------------------------------------
// STATE
// ---------------------------------------------------------------------------

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  String _selectedTarget = 'all';
  int _selectedPriority = 2;

// 🔥 AGGIUNTO tipo annuncio
  String _selectedType = 'avviso';

  bool _active = true;

  DateTime? _expiresAt;

// Modalità modifica
  String? _editingId;

  // ---------------------------------------------------------------------------
// SERVICES
// ---------------------------------------------------------------------------

  Future<void> _addAnnouncement() async {
    if (_titleController.text.trim().isEmpty ||
        _contentController.text.trim().isEmpty) {
      return;
    }

    await FirebaseFirestore.instance.collection('announcements').add({
      'title': _titleController.text.trim(),
      'message': _contentController.text.trim(),
      'target': _selectedTarget,
      'priority': _selectedPriority,
      'type': _selectedType, // 🔥 aggiunto
      'active': _active,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': _expiresAt,
    });

    _resetForm();

    if (mounted) Navigator.pop(context);
  }

  Future<void> _updateAnnouncement(String id) async {
    if (_titleController.text.trim().isEmpty ||
        _contentController.text.trim().isEmpty) {
      return;
    }

    await FirebaseFirestore.instance
        .collection('announcements')
        .doc(id)
        .update({
      'title': _titleController.text.trim(),
      'message': _contentController.text.trim(),
      'target': _selectedTarget,
      'priority': _selectedPriority,
      'type': _selectedType, // 🔥 aggiunto
      'active': _active,
      'expiresAt': _expiresAt,
    });

    _resetForm();

    if (mounted) Navigator.pop(context);
  }

  Future<void> _deleteAnnouncement(String id) async {
    await FirebaseFirestore.instance
        .collection('announcements')
        .doc(id)
        .delete();
  }

  Future<void> _toggleActive(String id, bool current) async {
    await FirebaseFirestore.instance
        .collection('announcements')
        .doc(id)
        .update({'active': !current});
  }

  void _resetForm() {
    _titleController.clear();
    _contentController.clear();
    _selectedTarget = 'all';
    _selectedPriority = 2;
    _selectedType = 'avviso'; // 🔥 aggiunto
    _active = true;
    _expiresAt = null;
  }

// ---------------------------------------------------------------------------
// UI HELPERS
// ---------------------------------------------------------------------------

  void _showAddDialog({
    String? id,
    Map<String, dynamic>? existingData,
  }) {
    if (existingData != null) {
      _editingId = id;
      _titleController.text = existingData['title'] ?? '';
      _contentController.text = existingData['message'] ?? '';

      final rawTarget = (existingData['target'] ?? 'all')
          .toString()
          .toLowerCase()
          .trim();
      _selectedTarget = _targets.contains(rawTarget) ? rawTarget : 'all';

      final rawType = (existingData['type'] ?? 'avviso')
          .toString()
          .toLowerCase()
          .trim();
      _selectedType = ['avviso', 'aggiornamento', 'alert'].contains(rawType)
          ? rawType
          : 'avviso';

      _active = existingData['active'] ?? true;
      _expiresAt = existingData['expiresAt'] != null
          ? existingData['expiresAt'].toDate()
          : null;
    } else {
      _editingId = null;
      _resetForm();
      _selectedType = 'avviso';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: SizedBox(
          width: 600,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: StatefulBuilder(
              builder: (context, setModalState) => SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    Text(
                      _editingId == null
                          ? "Nuovo annuncio"
                          : "Modifica annuncio",
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 24),

                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: "Titolo",
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 16),

                    TextField(
                      controller: _contentController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: "Messaggio",
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 24),

                    DropdownButtonFormField<String>(
                      value: _selectedTarget,
                      decoration: const InputDecoration(
                        labelText: "Target utenti",
                        border: OutlineInputBorder(),
                      ),
                      items: _targets
                          .map((t) => DropdownMenuItem(
                        value: t,
                        child: Text(t),
                      ))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setModalState(() => _selectedTarget = v);
                        }
                      },
                    ),

                    const SizedBox(height: 16),

                    DropdownButtonFormField<String>(
                      value: _selectedType,
                      decoration: const InputDecoration(
                        labelText: "Tipo annuncio",
                        border: OutlineInputBorder(),
                      ),
                      items: ['avviso', 'aggiornamento', 'alert']
                          .map((t) => DropdownMenuItem(
                        value: t,
                        child: Text(t),
                      ))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setModalState(() => _selectedType = v);
                        }
                      },
                    ),

                    const SizedBox(height: 16),

                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text("Attivo"),
                      value: _active,
                      onChanged: (v) {
                        setModalState(() => _active = v);
                      },
                    ),

                    const SizedBox(height: 16),

                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text("Scadenza (opzionale)"),
                      subtitle: Text(
                        _expiresAt == null
                            ? "Nessuna scadenza"
                            : _formatDate(_expiresAt!),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.date_range),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _expiresAt ?? DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime(2100),
                          );

                          if (picked != null) {
                            setModalState(() => _expiresAt = picked);
                          }
                        },
                      ),
                    ),

                    const SizedBox(height: 32),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text("Annulla"),
                        ),
                        const SizedBox(width: 16),
                        FilledButton(
                          onPressed: () async {

                            int totalUsers = 0;
                            final usersRef = FirebaseFirestore.instance.collection('users');

                            if (_selectedTarget == 'all') {
                              totalUsers = (await usersRef.get()).docs.length;
                            } else {
                              totalUsers = (await usersRef
                                  .where('type', isEqualTo: _selectedTarget)
                                  .get())
                                  .docs
                                  .length;
                            }

                            final data = {
                              'title': _titleController.text.trim(),
                              'message': _contentController.text.trim(),
                              'target': _selectedTarget,
                              'type': _selectedType,
                              'active': _active,
                              'expiresAt': _expiresAt,
                              'targetCount': totalUsers,
                              'seenCount': existingData?['seenCount'] ?? 0,
                            };

                            if (_editingId == null) {
                              await FirebaseFirestore.instance
                                  .collection('announcements')
                                  .add({
                                ...data,
                                'createdAt': FieldValue.serverTimestamp(),
                              });
                            } else {
                              await FirebaseFirestore.instance
                                  .collection('announcements')
                                  .doc(_editingId)
                                  .update({
                                ...data,
                                'createdAt': existingData?['createdAt'] ?? FieldValue.serverTimestamp(),
                              });
                            }

                            if (!mounted) return;
                            Navigator.pop(dialogContext);
                          },
                          child: Text(
                            _editingId == null ? "Salva" : "Aggiorna",
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

// ---------------------------------------------------------------------------
// BUILD
// ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Column(
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
              onPressed: () => _showAddDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Nuovo annuncio'),
            ),
          ],
        ),

        const SizedBox(height: 24),

        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('announcements')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {

              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(child: Text("Caricamento..."));
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Errore: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Text(
                    'Nessun annuncio presente',
                    style: TextStyle(color: Colors.black54),
                  ),
                );
              }

              final docs = snapshot.data!.docs;

              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {

                  final ann = docs[index].data() as Map<String, dynamic>;
                  final id = docs[index].id;

                  final created = ann['createdAt'] == null
                      ? ''
                      : _formatDate(ann['createdAt'].toDate());

                  final bool active = ann['active'] ?? false;
                  final String type = ann['type'] ?? 'avviso';

                  // ✅ NUOVI DATI
                  final int targetCount = ann['targetCount'] ?? 0;
                  final int seenCount = ann['seenCount'] ?? 0;

                  // 🎨 colore per tipo
                  Color bgColor;
                  switch (type) {
                    case 'alert':
                      bgColor = Colors.red.shade100;
                      break;
                    case 'aggiornamento':
                      bgColor = Colors.orange.shade100;
                      break;
                    default:
                      bgColor = Colors.blue.shade50;
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Card(
                      color: bgColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ann['title'] ?? '',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 17,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(ann['message'] ?? ''),
                                  const SizedBox(height: 8),
                                  Text(
                                    "Tipo: $type • Target: ${ann['target']} • ${active ? "Attivo" : "Disattivo"}",
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                    ),
                                  ),

                                  // 🔥 NUOVA RIGA STATISTICHE
                                  const SizedBox(height: 6),
                                  Text(
                                    "👥 $targetCount utenti • 👁 $seenCount visualizzazioni",
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black87,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 20),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  created,
                                  style: const TextStyle(fontSize: 12),
                                ),

                                // EDIT
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blue),
                                  tooltip: "Modifica",
                                  onPressed: () => _showAddDialog(
                                    id: id,
                                    existingData: ann,
                                  ),
                                ),

                                // VISIBILITY
                                IconButton(
                                  icon: Icon(
                                    active
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                  ),
                                  onPressed: () =>
                                      _toggleActive(id, active),
                                ),

                                // DELETE
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                  ),
                                  onPressed: () =>
                                      _deleteAnnouncement(id),
                                ),
                              ],
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
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // UTIL
  // ---------------------------------------------------------------------------

  String _formatDate(DateTime d) {
    return "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}";
  }
}