// lib/backoffice/pages/bk_courses_page.dart

// -----------------------------------------------------------------------------
// IMPORT
// -----------------------------------------------------------------------------
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../main.dart';

import 'bk_courses/storage_service.dart';
import 'bk_courses/courses_service.dart';
import 'bk_courses/course_dialog.dart';
import 'bk_courses/course_card.dart'; // 🔥 IMPORT AGGIUNTO

// -----------------------------------------------------------------------------
// PAGE
// -----------------------------------------------------------------------------
class BkCoursesPage extends StatefulWidget {
  const BkCoursesPage({super.key});

  @override
  State<BkCoursesPage> createState() =>
      _BkCoursesPageState();
}

// -----------------------------------------------------------------------------
// STATE
// -----------------------------------------------------------------------------
class _BkCoursesPageState
    extends State<BkCoursesPage> {
  double _uploadProgress = 0.0;
  bool _isUploading = false;

  // ---------------------------------------------------------------------------
  // ACTIONS - NEW COURSE
  // ---------------------------------------------------------------------------
  Future<void> _openNewCourseDialog() async {
    final courseRef =
    await CoursesService.createCourseSkeleton();

    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final tagsCtrl = TextEditingController();
    final contentsCtrl = TextEditingController();
    final attachmentsCtrl =
    TextEditingController();
    final videoCtrl = TextEditingController();
    final quizCtrl = TextEditingController();

    Map<String, dynamic>? quizData;

    showDialog(
      context: context,
      builder: (_) => CourseDialog(
        title: "Nuovo corso",
        titleCtrl: titleCtrl,
        descCtrl: descCtrl,
        tagsCtrl: tagsCtrl,
        contentsCtrl: contentsCtrl,
        attachmentsCtrl:
        attachmentsCtrl,
        videoCtrl: videoCtrl,
        quizCtrl: quizCtrl,
        category: "Pre-decadenza",
        onUploadFile: (ctrl) async {
          setState(() {
            _isUploading = true;
          });

          final fileName =
          await StorageService
              .uploadCourseAttachment(
            courseRef: courseRef,
            onProgress: (progress) {
              if (!mounted) return;
              setState(() {
                _uploadProgress =
                    progress;
              });
            },
          );

          if (fileName != null) {
            ctrl.text = ctrl.text.isEmpty
                ? fileName
                : "${ctrl.text}, $fileName";
          }

          if (mounted) {
            setState(() {
              _isUploading = false;
              _uploadProgress = 0.0;
            });
          }
        },
        onUploadQuiz: () async {
          quizData =
          await CoursesService
              .parseQuizXlsx();
          if (quizData != null) {
            quizCtrl.text =
            quizData!['fileName'];
            setState(() {});
          }
        },
        onDeleteQuiz: () {
          quizCtrl.clear();
          quizData = null;
          setState(() {});
        },
        onSave: (category) async {
          final title =
          titleCtrl.text.trim();

          if (title.isEmpty) return;

          await CoursesService
              .saveCourse(
            courseRef: courseRef,
            title: title,
            description:
            descCtrl.text.trim(),
            category: category,
            videoUrl:
            videoCtrl.text.trim(),
            tags: _split(tagsCtrl.text),
            contents:
            _split(contentsCtrl.text,
                separator: ';'),
            attachments:
            _split(attachmentsCtrl.text),
            quizData: quizData,
          );

          if (!mounted) return;
          Navigator.pop(context);
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ACTIONS - EDIT COURSE
  // ---------------------------------------------------------------------------
  Future<void> _openEditCourseDialog(
      DocumentSnapshot doc,
      Map<String, dynamic> data) async {
    final titleCtrl =
    TextEditingController(
        text: data['title'] ?? '');
    final descCtrl =
    TextEditingController(
        text: data['description'] ?? '');
    final tagsCtrl =
    TextEditingController(
        text: (data['tags'] as List?)
            ?.join(', ') ??
            '');
    final contentsCtrl =
    TextEditingController(
        text: (data['contents']
        as List?)
            ?.join('; ') ??
            '');
    final attachmentsCtrl =
    TextEditingController(
        text: (data['attachments']
        as List?)
            ?.join(', ') ??
            '');
    final videoCtrl =
    TextEditingController(
        text: data['videoUrl'] ?? '');
    final quizCtrl =
    TextEditingController();

    showDialog(
      context: context,
      builder: (_) => CourseDialog(
        title: "Modifica corso",
        titleCtrl: titleCtrl,
        descCtrl: descCtrl,
        tagsCtrl: tagsCtrl,
        contentsCtrl: contentsCtrl,
        attachmentsCtrl:
        attachmentsCtrl,
        videoCtrl: videoCtrl,
        quizCtrl: quizCtrl,
        category:
        data['category'] ??
            "Pre-decadenza",
        onUploadFile: (_) async {},
        onUploadQuiz: () async {},
        onDeleteQuiz: () {},
        onSave: (category) async {
          await doc.reference.update({
            'title':
            titleCtrl.text.trim(),
            'description':
            descCtrl.text.trim(),
            'category': category,
            'videoUrl':
            videoCtrl.text.trim(),
            'tags':
            _split(tagsCtrl.text),
            'contents': _split(
                contentsCtrl.text,
                separator: ';'),
            'attachments':
            _split(
                attachmentsCtrl
                    .text),
          });

          if (!mounted) return;
          Navigator.pop(context);
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ACTIONS - DELETE COURSE
  // ---------------------------------------------------------------------------
  Future<void> _deleteCourse(
      DocumentReference ref) async {
    await CoursesService
        .deleteCourseCompletely(ref);
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
      const EdgeInsets.all(16),
      child: Column(
        children: [
          if (_isUploading)
            LinearProgressIndicator(
                value:
                _uploadProgress),
          FilledButton.icon(
            onPressed:
            _openNewCourseDialog,
            icon:
            const Icon(Icons.add),
            label: const Text(
                "Nuovo corso"),
          ),
          const SizedBox(
              height: 16),
          Expanded(
            child:
            StreamBuilder<
                QuerySnapshot>(
              stream: formDb
                  .collection(
                  'courses')
                  .orderBy(
                  'createdAt')
                  .snapshots(),
              builder: (context,
                  snapshot) {
                if (!snapshot
                    .hasData) {
                  return const Center(
                    child:
                    CircularProgressIndicator(),
                  );
                }

                final docs =
                    snapshot
                        .data!
                        .docs;

                if (docs.isEmpty) {
                  return const Center(
                      child: Text(
                          "Nessun corso disponibile"));
                }

                return ListView.builder(
                  itemCount:
                  docs.length,
                  itemBuilder:
                      (context, i) {
                    final doc =
                    docs[i];
                    final data = doc
                        .data()
                    as Map<
                        String,
                        dynamic>;

                    return CourseCard(
                      doc: doc,
                      onDelete: () =>
                          _deleteCourse(
                              doc.reference),
                      onEdit: () =>
                          _openEditCourseDialog(
                              doc, data),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------
  List<String> _split(
      String text, {
        String separator = ',',
      }) {
    return text
        .split(separator)
        .map((e) => e.trim())
        .where((e) =>
    e.isNotEmpty)
        .toList();
  }
}
