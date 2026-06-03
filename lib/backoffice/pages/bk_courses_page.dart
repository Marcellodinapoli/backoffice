import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:excel/excel.dart' as ex;

import '../../main.dart';
import '../utils/bk_storage_upload.dart';
import 'bk_courses/course_card.dart';

// -----------------------------------------------------------------------------
// PAGE
// -----------------------------------------------------------------------------
class BkCoursesPage extends StatefulWidget {
  const BkCoursesPage({super.key});

  @override
  State<BkCoursesPage> createState() => _BkCoursesPageState();
}

class _BkCoursesPageState extends State<BkCoursesPage> {

  // ---------------------------------------------------------------------------
  // STATE
  // ---------------------------------------------------------------------------
  double _uploadProgress = 0.0;
  bool _isUploading = false;

  // ---------------------------------------------------------------------------
  // ---------------------------------------------------------------------------
  // SERVICES - NEW COURSE
  // ---------------------------------------------------------------------------
  Future<void> _openNewCourseDialog() async {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final videoCtrl = TextEditingController();
    final tagsCtrl = TextEditingController();
    final contentsCtrl = TextEditingController();

    final List<Map<String, String>> attachments = [];

    Map<String, dynamic>? quizData;
    String category = 'Sollecito';

    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: SizedBox(
          width: 520,
          child: StatefulBuilder(
            builder: (context, setModalState) => Padding(
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    const Text(
                      "Nuovo corso",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 24),

                    DropdownButtonFormField<String>(
                      value: category,
                      items: const [
                        DropdownMenuItem(
                          value: 'Sollecito',
                          child: Text('Sollecito'),
                        ),
                        DropdownMenuItem(
                          value: 'Recupero',
                          child: Text('Recupero'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setModalState(() => category = value);
                        }
                      },
                      decoration: const InputDecoration(
                        labelText: "Categoria",
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 16),

                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText: "Titolo",
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 16),

                    TextField(
                      controller: descCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: "Descrizione",
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 16),

                    TextField(
                      controller: contentsCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: "Cosa contiene (separa con ';')",
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 16),

                    TextField(
                      controller: videoCtrl,
                      decoration: const InputDecoration(
                        labelText: "Link video",
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 24),

                    const Text(
                      "Allegati",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 12),

                    FilledButton.icon(
                      onPressed: () async {
                        try {
                          final result = await FilePicker.platform.pickFiles(
                            withData: true,
                          );
                          if (result == null) return;

                          final file = result.files.first;
                          final fileName = file.name;

                          setModalState(() {
                            _isUploading = true;
                            _uploadProgress = 0;
                          });

                          final ref = FirebaseStorage.instance
                              .ref()
                              .child(
                              'courses/${DateTime.now().millisecondsSinceEpoch}_$fileName');

                          final uploadTask = await startStorageUpload(
                            ref: ref,
                            file: file,
                          );

                          uploadTask.snapshotEvents.listen((event) {
                            if (event.totalBytes > 0) {
                              setModalState(() {
                                _uploadProgress =
                                    event.bytesTransferred / event.totalBytes;
                              });
                            }
                          });

                          final snapshot = await uploadTask;
                          final downloadUrl =
                          await snapshot.ref.getDownloadURL();

                          setModalState(() {
                            attachments.add({
                              'name': fileName,
                              'url': downloadUrl,
                            });
                            _isUploading = false;
                            _uploadProgress = 0;
                          });
                        } catch (e) {
                          setModalState(() {
                            _isUploading = false;
                            _uploadProgress = 0;
                          });
                        }
                      },
                      icon: const Icon(Icons.upload_file),
                      label: const Text("Carica allegato"),
                    ),

                    if (_isUploading) ...[
                      const SizedBox(height: 12),
                      LinearProgressIndicator(value: _uploadProgress),
                    ],

                    const SizedBox(height: 12),

                    ...attachments.map((file) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        file['name'] ?? '',
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          try {
                            if (file['url'] != null) {
                              await FirebaseStorage.instance
                                  .refFromURL(file['url']!)
                                  .delete();
                            }
                          } catch (_) {}

                          setModalState(() {
                            attachments.remove(file);
                          });
                        },
                      ),
                    )),

                    const SizedBox(height: 24),

                    FilledButton.icon(
                      onPressed: () async {
                        final result =
                        await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['xlsx'],
                          withData: true,
                        );

                        if (result == null) return;

                        final bytes = result.files.first.bytes;
                        if (bytes == null) return;

                        final excel = ex.Excel.decodeBytes(bytes);
                        final sheet = excel.tables.values.first;

                        final questions = <Map<String, dynamic>>[];

                        for (int i = 1; i < sheet.maxRows; i++) {
                          final row = sheet.row(i);
                          questions.add({
                            'question': row[0]?.value.toString(),
                            'options': [
                              row[1]?.value.toString(),
                              row[2]?.value.toString(),
                              row[3]?.value.toString(),
                            ],
                            'correctIndex':
                            int.tryParse(
                                row[4]?.value.toString() ?? '0') ??
                                0,
                          });
                        }

                        setModalState(() {
                          quizData = {
                            'fileName': result.files.first.name,
                            'questions': questions,
                            'timeLimit': 60,
                          };
                        });

                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text("✅ Quiz caricato")),
                        );
                      },
                      icon: const Icon(Icons.quiz),
                      label: const Text("Carica quiz (.xlsx)"),
                    ),

                    if (quizData != null) ...[
                      const SizedBox(height: 12),
                      Text("Quiz: ${quizData?['fileName'] ?? 'Senza titolo'}"),
                    ],

                    const SizedBox(height: 24),

                    TextField(
                      controller: tagsCtrl,
                      decoration: const InputDecoration(
                        labelText: "Tag (separati da virgola)",
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
                            if (titleCtrl.text.trim().isEmpty) return;

                            await formDb.collection('courses').add({
                              'title': titleCtrl.text.trim(),
                              'description': descCtrl.text.trim(),
                              'category': category,
                              'videoUrl': videoCtrl.text.trim(),
                              'tags': _split(tagsCtrl.text),
                              'contents':
                              _split(contentsCtrl.text, separator: ';'),
                              'attachments': attachments,
                              'quiz': quizData,
                              'createdAt':
                              FieldValue.serverTimestamp(),
                            });

                            if (!context.mounted) return;
                            Navigator.pop(context);
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

  // ---------------------------------------------------------------------------
  // SERVICES - DELETE COURSE (WITH CONFIRM)
  // ---------------------------------------------------------------------------
  Future<void> _deleteCourse(DocumentReference docRef) async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        backgroundColor: Colors.white,
        child: SizedBox(
          width: 420,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 28,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Conferma eliminazione",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Sei sicuro di voler eliminare definitivamente questo corso?",
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text("Annulla"),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context, true),
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

    if (confirm != true) return;

    try {
      // 🔎 Recupero dati corso prima della cancellazione
      final snapshot = await docRef.get();
      final data = snapshot.data() as Map<String, dynamic>?;

      if (data != null) {
        // ---------------------------
        // ELIMINA ALLEGATI DA STORAGE
        // ---------------------------
        final List attachments = (data['attachments'] as List?) ?? [];
        for (final item in attachments) {
          try {
            if (item is Map && item['url'] != null) {
              await FirebaseStorage.instance
                  .refFromURL(item['url'].toString())
                  .delete();
            }
          } catch (_) {}
        }

        // ---------------------------
        // ELIMINA QUIZ (SE PRESENTE)
        // ---------------------------
        final Map<String, dynamic>? quiz =
        data['quiz'] as Map<String, dynamic>?;

        if (quiz != null && quiz['fileUrl'] != null) {
          try {
            await FirebaseStorage.instance
                .refFromURL(quiz['fileUrl'].toString())
                .delete();
          } catch (_) {}
        }
      }

      // ---------------------------
      // ELIMINA DOCUMENTO FIRESTORE
      // ---------------------------
      await docRef.delete();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("🗑️ Corso eliminato completamente")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Errore eliminazione: $e")),
      );
    }
  }

  // ---------------------------------------------------------------------------
// SERVICES - EDIT COURSE (FULL EDIT)
// ---------------------------------------------------------------------------
  Future<void> _openEditDialog(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;

    final titleCtrl = TextEditingController(text: data['title'] ?? '');
    final descCtrl = TextEditingController(text: data['description'] ?? '');
    final videoCtrl = TextEditingController(text: data['videoUrl'] ?? '');
    final tagsCtrl =
    TextEditingController(text: (data['tags'] as List?)?.join(', ') ?? '');
    final contentsCtrl =
    TextEditingController(text: (data['contents'] as List?)?.join('; ') ?? '');

    List<Map<String, String>> attachments =
    (data['attachments'] as List? ?? [])
        .map<Map<String, String>>((item) {
      if (item is Map) {
        return {
          'name': item['name']?.toString() ?? '',
          'url': item['url']?.toString() ?? '',
        };
      }
      return {
        'name': item.toString(),
        'url': item.toString(),
      };
    }).toList();

    Map<String, dynamic>? quizData = data['quiz'];

    String category = data['category'] ?? 'Sollecito';
    if (category != 'Sollecito' && category != 'Recupero') {
      category = 'Sollecito';
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
          width: 520,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: StatefulBuilder(
              builder: (context, setModalState) => SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    const Text(
                      "Modifica corso",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 24),

                    DropdownButtonFormField<String>(
                      value: category,
                      items: const [
                        DropdownMenuItem(
                          value: 'Sollecito',
                          child: Text('Sollecito'),
                        ),
                        DropdownMenuItem(
                          value: 'Recupero',
                          child: Text('Recupero'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setModalState(() => category = value);
                        }
                      },
                      decoration: const InputDecoration(
                        labelText: "Categoria",
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 16),

                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText: "Titolo",
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 16),

                    TextField(
                      controller: descCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: "Descrizione",
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 16),

                    TextField(
                      controller: contentsCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: "Cosa contiene (separa con ';')",
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 16),

                    TextField(
                      controller: videoCtrl,
                      decoration: const InputDecoration(
                        labelText: "Link video",
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 24),

                    Text("Allegati",
                        style: Theme.of(context).textTheme.titleMedium),

                    const SizedBox(height: 12),

                    ElevatedButton.icon(
                      onPressed: () async {
                        final result =
                        await FilePicker.platform.pickFiles(withData: true);
                        if (result == null) return;

                        final file = result.files.first;
                        final fileName = file.name;

                        final ref = FirebaseStorage.instance
                            .ref('courses/${DateTime.now().millisecondsSinceEpoch}_$fileName');

                        final uploadTask = await startStorageUpload(
                          ref: ref,
                          file: file,
                        );

                        final snapshot = await uploadTask;
                        final downloadUrl =
                        await snapshot.ref.getDownloadURL();

                        setModalState(() {
                          attachments.add({
                            'name': fileName,
                            'url': downloadUrl,
                          });
                        });
                      },
                      icon: const Icon(Icons.upload_file),
                      label: const Text("Carica allegato"),
                    ),

                    const SizedBox(height: 12),

                    ...attachments.map((file) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        file['name'] ?? '',
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        icon:
                        const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          try {
                            if (file['url'] != null &&
                                file['url']!.isNotEmpty) {
                              await FirebaseStorage.instance
                                  .refFromURL(file['url']!)
                                  .delete();
                            }
                          } catch (_) {}
                          setModalState(() {
                            attachments.remove(file);
                          });
                        },
                      ),
                    )),

                    const SizedBox(height: 24),

                    Text("Quiz",
                        style: Theme.of(context).textTheme.titleMedium),

                    const SizedBox(height: 12),

                    ElevatedButton.icon(
                      onPressed: () async {
                        final result =
                        await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['xlsx'],
                          withData: true,
                        );
                        if (result == null) return;

                        // Se esiste già un quiz, lo elimino da Storage
                        if (quizData != null &&
                            quizData!['fileUrl'] != null) {
                          try {
                            await FirebaseStorage.instance
                                .refFromURL(quizData!['fileUrl'])
                                .delete();
                          } catch (_) {}
                        }

                        final bytes = result.files.first.bytes!;
                        final fileName = result.files.first.name;

                        final ref = FirebaseStorage.instance
                            .ref('courses/${DateTime.now().millisecondsSinceEpoch}_$fileName');

                        final snapshot = await ref.putData(bytes);
                        final fileUrl =
                        await snapshot.ref.getDownloadURL();

                        final excel = ex.Excel.decodeBytes(bytes);
                        final sheet = excel.tables.values.first;

                        final questions = <Map<String, dynamic>>[];

                        for (int i = 1; i < sheet.maxRows; i++) {
                          final row = sheet.row(i);
                          questions.add({
                            'question': row[0]?.value.toString(),
                            'options': [
                              row[1]?.value.toString(),
                              row[2]?.value.toString(),
                              row[3]?.value.toString(),
                            ],
                            'correctIndex':
                            int.tryParse(
                                row[4]?.value.toString() ?? '0') ??
                                0,
                          });
                        }

                        setModalState(() {
                          quizData = {
                            'fileName': fileName,
                            'fileUrl': fileUrl,
                            'questions': questions,
                            'timeLimit': 60,
                          };
                        });

                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text("Quiz aggiornato")),
                        );
                      },
                      icon: const Icon(Icons.quiz),
                      label:
                      const Text("Carica / Sostituisci quiz (.xlsx)"),
                    ),

                    if (quizData != null) ...[
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                            "Quiz: ${quizData?['fileName'] ?? ''}"),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete,
                              color: Colors.red),
                          onPressed: () async {
                            try {
                              if (quizData?['fileUrl'] != null) {
                                await FirebaseStorage.instance
                                    .refFromURL(
                                    quizData!['fileUrl'])
                                    .delete();
                              }
                            } catch (_) {}

                            setModalState(() {
                              quizData = null;
                            });
                          },
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    TextField(
                      controller: tagsCtrl,
                      decoration: const InputDecoration(
                        labelText: "Tag (separati da virgola)",
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 32),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () =>
                              Navigator.pop(context),
                          child: const Text("Annulla"),
                        ),
                        const SizedBox(width: 12),
                        FilledButton(
                          onPressed: () async {
                            await doc.reference.update({
                              'title': titleCtrl.text.trim(),
                              'description':
                              descCtrl.text.trim(),
                              'category': category,
                              'videoUrl':
                              videoCtrl.text.trim(),
                              'tags': _split(tagsCtrl.text),
                              'contents': _split(
                                  contentsCtrl.text,
                                  separator: ';'),
                              'attachments': attachments,
                              'quiz': quizData,
                            });

                            if (!context.mounted) return;
                            Navigator.pop(context);
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

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            if (_isUploading) ...[
              LinearProgressIndicator(value: _uploadProgress),
              const SizedBox(height: 8),
            ],

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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                  ),
                  onPressed: _openNewCourseDialog,
                  icon: const Icon(Icons.add),
                  label: const Text("Nuovo corso"),
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
                        .collection('courses')
                        .where('category', isEqualTo: 'Sollecito')
                        .orderBy('createdAt')
                        .snapshots(),
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
                          child: Text("Nessun corso disponibile"),
                        );
                      }

                      final docs = snapshot.data!.docs;

                      return ListView.separated(
                        separatorBuilder: (_, __) =>
                        const SizedBox(height: 8),
                        itemCount: docs.length,
                        itemBuilder: (_, i) {
                          return CourseCard(
                            doc: docs[i],
                            onDelete: () =>
                                _deleteCourse(docs[i].reference),
                            onEdit: () =>
                                _openEditDialog(docs[i]),
                          );
                        },
                      );
                    },
                  ),

                  // ---------------- RECUPERO ----------------
                  StreamBuilder<QuerySnapshot>(
                    stream: formDb
                        .collection('courses')
                        .where('category', isEqualTo: 'Recupero')
                        .orderBy('createdAt')
                        .snapshots(),
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
                          child: Text("Nessun corso disponibile"),
                        );
                      }

                      final docs = snapshot.data!.docs;

                      return ListView.separated(
                        separatorBuilder: (_, __) =>
                        const SizedBox(height: 8),
                        itemCount: docs.length,
                        itemBuilder: (_, i) {
                          return CourseCard(
                            doc: docs[i],
                            onDelete: () =>
                                _deleteCourse(docs[i].reference),
                            onEdit: () =>
                                _openEditDialog(docs[i]),
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
    );
  }


  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------
  List<String> _split(String text, {String separator = ','}) {
    return text
        .split(separator)
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }
}
