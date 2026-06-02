  // ============================================================
  // CONFIG / IMPORT
  // ============================================================

  import 'package:flutter/material.dart';
  import 'package:cloud_firestore/cloud_firestore.dart';
  import 'package:firebase_auth/firebase_auth.dart';
  import '../../main.dart';

  class BkRoleplayPage extends StatefulWidget {
    const BkRoleplayPage({super.key});

    @override
    State<BkRoleplayPage> createState() => _BkRoleplayPageState();
  }

  class _BkRoleplayPageState extends State<BkRoleplayPage> {

    // ============================================================
    // STATE
    // ============================================================

    // ============================================================
  // SERVICES / HELPERS
  // ============================================================

    Future<void> _refreshToken() async {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      await user.getIdToken(true);
    }

    // ============================================================
// ACTIONS - EDIT
// ============================================================

    void _editRoleplayDialog(DocumentSnapshot doc) {
      final data = doc.data() as Map<String, dynamic>;

      final titleCtrl = TextEditingController(text: data["title"] ?? "");
      final promptCtrl = TextEditingController(text: data["prompt"] ?? "");

      String category = data["category"] ?? "Sollecito";

      if (category != "Sollecito" && category != "Recupero") {
        category = "Sollecito";
      }

      // ---------------- PRACTICE DATA ----------------
      List<Map<String, TextEditingController>> practiceData = [];

      final existingData = (data["practiceData"] as List?) ?? [];

      for (var row in existingData) {
        practiceData.add({
          "label": TextEditingController(text: row["label"] ?? ""),
          "value": TextEditingController(text: row["value"] ?? ""),
        });
      }

      if (practiceData.isEmpty) {
        practiceData.add({
          "label": TextEditingController(),
          "value": TextEditingController(),
        });
      }

      void addRow() {
        practiceData.add({
          "label": TextEditingController(),
          "value": TextEditingController(),
        });
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => Dialog(
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

                      const Text(
                        "Modifica simulazione",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 24),

                      DropdownButtonFormField<String>(
                        value: category,
                        decoration: const InputDecoration(
                          labelText: "Categoria",
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: "Sollecito",
                            child: Text("Sollecito"),
                          ),
                          DropdownMenuItem(
                            value: "Recupero",
                            child: Text("Recupero"),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setModalState(() => category = v);
                          }
                        },
                      ),

                      const SizedBox(height: 16),

                      TextField(
                        controller: titleCtrl,
                        decoration: const InputDecoration(
                          labelText: "Titolo",
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 24),

                      const Text(
                        "Dati pratica",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),

                      const SizedBox(height: 12),

                      ...practiceData.asMap().entries.map((entry) {
                        final index = entry.key;
                        final row = entry.value;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: row["label"],
                                  decoration: const InputDecoration(
                                    labelText: "Etichetta",
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: row["value"],
                                  decoration: const InputDecoration(
                                    labelText: "Valore",
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () {
                                  setModalState(() {
                                    practiceData.removeAt(index);
                                  });
                                },
                              )
                            ],
                          ),
                        );
                      }),

                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () {
                            setModalState(() {
                              addRow();
                            });
                          },
                          icon: const Icon(Icons.add),
                          label: const Text("Aggiungi riga"),
                        ),
                      ),

                      const SizedBox(height: 24),

                      TextField(
                        controller: promptCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: "Prompt",
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 32),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text("Annulla"),
                          ),
                          const SizedBox(width: 16),
                          FilledButton(
                            onPressed: () async {
                              await _refreshToken();

                              final formattedPracticeData = practiceData
                                  .where((row) =>
                              row["label"]!.text.trim().isNotEmpty &&
                                  row["value"]!.text.trim().isNotEmpty)
                                  .map((row) => {
                                "label": row["label"]!.text.trim(),
                                "value": row["value"]!.text.trim(),
                              })
                                  .toList();

                              await doc.reference.update({
                                "title": titleCtrl.text.trim(),
                                "category": category,
                                "prompt": promptCtrl.text.trim(),
                                "practiceData": formattedPracticeData,
                              });

                              if (!context.mounted) return;
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("✅ Simulazione aggiornata"),
                                ),
                              );
                            },
                            child: const Text("Salva"),
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
// ============================================================
// ACTIONS - ADD
// ============================================================

    void _addRoleplayDialog() {
      final titleCtrl = TextEditingController();
      final promptCtrl = TextEditingController();

      String category = "Sollecito";

      List<Map<String, TextEditingController>> practiceData = [];

      void addRow() {
        practiceData.add({
          "label": TextEditingController(),
          "value": TextEditingController(),
        });
      }

      addRow(); // prima riga di default

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

                      const Text(
                        "Nuova simulazione",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 24),

                      DropdownButtonFormField<String>(
                        value: category,
                        decoration: const InputDecoration(
                          labelText: "Categoria",
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: "Sollecito",
                            child: Text("Sollecito"),
                          ),
                          DropdownMenuItem(
                            value: "Recupero",
                            child: Text("Recupero"),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() => category = val);
                          }
                        },
                      ),

                      const SizedBox(height: 16),

                      TextField(
                        controller: titleCtrl,
                        decoration: const InputDecoration(
                          labelText: "Titolo simulazione",
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 24),

                      const Text(
                        "Dati pratica",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),

                      const SizedBox(height: 12),

                      ...practiceData.asMap().entries.map((entry) {
                        final index = entry.key;
                        final row = entry.value;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: row["label"],
                                  decoration: const InputDecoration(
                                    labelText: "Etichetta (es. Nome debitore)",
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: row["value"],
                                  decoration: const InputDecoration(
                                    labelText: "Valore",
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () {
                                  setModalState(() {
                                    practiceData.removeAt(index);
                                  });
                                },
                              )
                            ],
                          ),
                        );
                      }),

                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () {
                            setModalState(() {
                              addRow();
                            });
                          },
                          icon: const Icon(Icons.add),
                          label: const Text("Aggiungi riga"),
                        ),
                      ),

                      const SizedBox(height: 24),

                      TextField(
                        controller: promptCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: "Prompt",
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 32),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            child: const Text("Annulla"),
                          ),
                          const SizedBox(width: 16),
                          FilledButton(
                            onPressed: () async {
                              if (titleCtrl.text.trim().isEmpty) return;

                              try {
                                await _refreshToken();

                                final user = FirebaseAuth.instance.currentUser;
                                final token = await user?.getIdTokenResult(true);
                                debugPrint("CLAIMS: ${token?.claims}");

                                final formattedPracticeData = practiceData
                                    .where((row) =>
                                row["label"]!.text.trim().isNotEmpty &&
                                    row["value"]!.text.trim().isNotEmpty)
                                    .map((row) => {
                                  "label": row["label"]!.text.trim(),
                                  "value": row["value"]!.text.trim(),
                                })
                                    .toList();

                                await FirebaseFirestore.instance
                                    .collection("roleplay")
                                    .add({
                                  "title": titleCtrl.text.trim(),
                                  "category": category,
                                  "prompt": promptCtrl.text.trim(),
                                  "practiceData": formattedPracticeData,
                                  "date": DateTime.now().toIso8601String(),
                                });

                                if (!dialogContext.mounted) return;
                                Navigator.of(dialogContext, rootNavigator: true).pop();

                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("✅ Simulazione salvata"),
                                  ),
                                );

                              } catch (e) {
                                debugPrint("ERRORE FIRESTORE: $e");

                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text("❌ Errore: $e"),
                                  ),
                                );
                              }
                            },
                            child: const Text("Salva"),
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
// ============================================================
// ACTIONS - OTHER
// ============================================================

    void _showPromptDialog(String docId, String title, String? value) {
      final promptCtrl = TextEditingController(text: value ?? "");

      showDialog(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: SizedBox(
            width: 600,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Prompt - $title",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: promptCtrl,
                    maxLines: 10,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Chiudi"),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF1565C0),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () async {
                          await _refreshToken();
                          await FirebaseFirestore.instance
                              .collection("roleplay")
                              .doc(docId)
                              .update({"prompt": promptCtrl.text.trim()});

                          if (!mounted) return;
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Prompt aggiornato"),
                            ),
                          );
                        },
                        child: const Text("Salva"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    void _removeRoleplay(String docId) {
      showDialog(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: SizedBox(
            width: 600,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Conferma eliminazione",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Sei sicuro di voler eliminare questa simulazione?",
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Annulla"),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () async {
                          Navigator.pop(context);

                          await _refreshToken();
                          await FirebaseFirestore.instance
                              .collection("roleplay")
                              .doc(docId)
                              .delete();

                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Simulazione eliminata"),
                            ),
                          );
                        },
                        child: const Text("Elimina"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

// ============================================================
// BUILD
// ============================================================

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Material(
          color: Colors.transparent,
          child: DefaultTabController(
            length: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: TabBar(
                          isScrollable: true,
                          labelColor: Colors.black,
                          unselectedLabelColor: Colors.grey,
                          indicatorColor: Color(0xFF1565C0),
                          tabs: [
                            Tab(text: "Sollecito"),
                            Tab(text: "Recupero"),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF1565C0),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text('Nuova simulazione'),
                        onPressed: _addRoleplayDialog,
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  Expanded(
                    child: TabBarView(
                      children: [

                        // ---------------- SOLLECITO ----------------
                        StreamBuilder<QuerySnapshot>(
                          stream: formDb
                              .collection("roleplay")
                              .where("category", isEqualTo: "Sollecito")
                              .orderBy("date", descending: true)
                              .snapshots(),
                          builder: (context, snap) {
                            if (!snap.hasData) {
                              return const Center(child: CircularProgressIndicator());
                            }

                            final docs = snap.data!.docs;

                            if (docs.isEmpty) {
                              return const Center(
                                child: Text(
                                  'Nessuna simulazione disponibile',
                                  style: TextStyle(color: Colors.black54),
                                ),
                              );
                            }

                            return ListView.separated(
                              itemCount: docs.length,
                              separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                              itemBuilder: (_, i) {
                                final d = docs[i];
                                final data = d.data() as Map<String, dynamic>;

                                final title = data["title"] ?? "";
                                final category = data["category"] ?? "";
                                final audioUrl = data.containsKey("audioUrl")
                                    ? data["audioUrl"] ?? ""
                                    : "";
                                final prompt = data["prompt"];
                                final practiceData = data["practiceData"] as List<dynamic>?;

                                final date =
                                    DateTime.tryParse(data["date"] ?? "") ??
                                        DateTime.now();

                                return ListTile(
                                  title: Text(
                                    title,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        audioUrl.isNotEmpty
                                            ? "$category • $audioUrl • Inserito il ${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}"
                                            : "$category • Inserito il ${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}",
                                      ),

                                      if (practiceData != null)
                                        ...practiceData.map((item) {
                                          final label = item["label"] ?? "";
                                          final value = item["value"] ?? "";
                                          return Padding(
                                            padding: const EdgeInsets.only(top: 4),
                                            child: RichText(
                                              text: TextSpan(
                                                style: const TextStyle(
                                                    color: Colors.black87),
                                                children: [
                                                  TextSpan(
                                                    text: "$label: ",
                                                    style: const TextStyle(
                                                        fontWeight: FontWeight.bold),
                                                  ),
                                                  TextSpan(text: value),
                                                ],
                                              ),
                                            ),
                                          );
                                        }),

                                      const SizedBox(height: 4),
                                      const Text(
                                        "Prompt: [clicca Vedi]",
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                  trailing: PopupMenuButton<String>(
                                    onSelected: (value) {
                                      if (value == "edit") {
                                        _editRoleplayDialog(d);
                                      } else if (value == "delete") {
                                        _removeRoleplay(d.id);
                                      } else if (value == "prompt") {
                                        _showPromptDialog(
                                            d.id, title, prompt);
                                      }
                                    },
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(
                                        value: "edit",
                                        child: Text("Modifica"),
                                      ),
                                      PopupMenuItem(
                                        value: "delete",
                                        child: Text("Elimina"),
                                      ),
                                      PopupMenuItem(
                                        value: "prompt",
                                        child:
                                        Text("Vedi/Modifica Prompt"),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        ),

                        // ---------------- RECUPERO ----------------
                        StreamBuilder<QuerySnapshot>(
                          stream: formDb
                              .collection("roleplay")
                              .where("category", isEqualTo: "Recupero")
                              .orderBy("date", descending: true)
                              .snapshots(),
                          builder: (context, snap) {
                            if (!snap.hasData) {
                              return const Center(child: CircularProgressIndicator());
                            }

                            final docs = snap.data!.docs;

                            if (docs.isEmpty) {
                              return const Center(
                                child: Text(
                                  'Nessuna simulazione disponibile',
                                  style: TextStyle(color: Colors.black54),
                                ),
                              );
                            }

                            return ListView.separated(
                              itemCount: docs.length,
                              separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                              itemBuilder: (_, i) {
                                final d = docs[i];
                                final data = d.data() as Map<String, dynamic>;

                                final title = data["title"] ?? "";
                                final category = data["category"] ?? "";
                                final audioUrl = data.containsKey("audioUrl")
                                    ? data["audioUrl"] ?? ""
                                    : "";
                                final prompt = data["prompt"];
                                final practiceData = data["practiceData"] as List<dynamic>?;

                                final date =
                                    DateTime.tryParse(data["date"] ?? "") ??
                                        DateTime.now();

                                return ListTile(
                                  title: Text(
                                    title,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        audioUrl.isNotEmpty
                                            ? "$category • $audioUrl • Inserito il ${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}"
                                            : "$category • Inserito il ${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}",
                                      ),

                                      if (practiceData != null)
                                        ...practiceData.map((item) {
                                          final label = item["label"] ?? "";
                                          final value = item["value"] ?? "";
                                          return Padding(
                                            padding: const EdgeInsets.only(top: 4),
                                            child: RichText(
                                              text: TextSpan(
                                                style: const TextStyle(
                                                    color: Colors.black87),
                                                children: [
                                                  TextSpan(
                                                    text: "$label: ",
                                                    style: const TextStyle(
                                                        fontWeight: FontWeight.bold),
                                                  ),
                                                  TextSpan(text: value),
                                                ],
                                              ),
                                            ),
                                          );
                                        }),

                                      const SizedBox(height: 4),
                                      const Text(
                                        "Prompt: [clicca Vedi]",
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                  trailing: PopupMenuButton<String>(
                                    onSelected: (value) {
                                      if (value == "edit") {
                                        _editRoleplayDialog(d);
                                      } else if (value == "delete") {
                                        _removeRoleplay(d.id);
                                      } else if (value == "prompt") {
                                        _showPromptDialog(
                                            d.id, title, prompt);
                                      }
                                    },
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(
                                        value: "edit",
                                        child: Text("Modifica"),
                                      ),
                                      PopupMenuItem(
                                        value: "delete",
                                        child: Text("Elimina"),
                                      ),
                                      PopupMenuItem(
                                        value: "prompt",
                                        child:
                                        Text("Vedi/Modifica Prompt"),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
  }
