// lib/backoffice/pages/bk_courses/course_dialog.dart

// -----------------------------------------------------------------------------
// IMPORT
// -----------------------------------------------------------------------------
import 'package:flutter/material.dart';

// -----------------------------------------------------------------------------
// COURSE DIALOG
// -----------------------------------------------------------------------------
class CourseDialog extends StatefulWidget {
  final String title;

  final TextEditingController titleCtrl;
  final TextEditingController descCtrl;
  final TextEditingController tagsCtrl;
  final TextEditingController contentsCtrl;
  final TextEditingController attachmentsCtrl;
  final TextEditingController videoCtrl;
  final TextEditingController quizCtrl;

  final String category;

  final Future<void> Function(TextEditingController) onUploadFile;
  final Future<void> Function() onUploadQuiz;
  final VoidCallback onDeleteQuiz;
  final Future<void> Function(String) onSave;

  const CourseDialog({
    super.key,
    required this.title,
    required this.titleCtrl,
    required this.descCtrl,
    required this.tagsCtrl,
    required this.contentsCtrl,
    required this.attachmentsCtrl,
    required this.videoCtrl,
    required this.quizCtrl,
    required this.category,
    required this.onUploadFile,
    required this.onUploadQuiz,
    required this.onDeleteQuiz,
    required this.onSave,
  });

  @override
  State<CourseDialog> createState() => _CourseDialogState();
}

// -----------------------------------------------------------------------------
// STATE
// -----------------------------------------------------------------------------
class _CourseDialogState extends State<CourseDialog> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late String _selectedCategory;

  // ---------------------------------------------------------------------------
  // LIFECYCLE
  // ---------------------------------------------------------------------------
  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.category;

    widget.quizCtrl.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFFF5F5F5),
      title: Text(widget.title),
      content: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _scrollController,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildCategoryDropdown(),
                const SizedBox(height: 12),
                _buildTextField(widget.titleCtrl, "Titolo del corso"),
                const SizedBox(height: 12),
                _buildTextField(
                  widget.descCtrl,
                  "Descrizione",
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  widget.contentsCtrl,
                  "Cosa contiene (separa con ';')",
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  widget.videoCtrl,
                  "Link del video",
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  widget.attachmentsCtrl,
                  "Allegati (link separati da virgola)",
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () =>
                      widget.onUploadFile(widget.attachmentsCtrl),
                  icon: const Icon(Icons.upload_file),
                  label: const Text("Carica file"),
                ),
                const SizedBox(height: 12),
                if (widget.quizCtrl.text.isNotEmpty)
                  _buildQuizPreview(),
                ElevatedButton.icon(
                  onPressed: widget.onUploadQuiz,
                  icon: const Icon(Icons.quiz),
                  label: const Text("Carica quiz (.xlsx)"),
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  widget.tagsCtrl,
                  "Tag (separati da virgola)",
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            if (mounted) Navigator.pop(context);
          },
          child: const Text("Annulla"),
        ),
        FilledButton(
          onPressed: () async {
            await widget.onSave(_selectedCategory);
          },
          child: const Text("Salva"),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // UI HELPERS
  // ---------------------------------------------------------------------------
  Widget _buildCategoryDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedCategory,
      items: const [
        DropdownMenuItem(
          value: 'Pre-decadenza',
          child: Text('Pre-decadenza'),
        ),
        DropdownMenuItem(
          value: 'Post-decadenza',
          child: Text('Post-decadenza'),
        ),
      ],
      onChanged: (value) {
        if (value != null) {
          setState(() {
            _selectedCategory = value;
          });
        }
      },
      decoration: const InputDecoration(
        labelText: "Categoria",
        border: OutlineInputBorder(),
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller,
      String label, {
        int maxLines = 1,
      }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _buildQuizPreview() {
    return Row(
      children: [
        Expanded(
          child: Text(
            "Quiz caricato: ${widget.quizCtrl.text}",
            style: const TextStyle(
              fontStyle: FontStyle.italic,
              color: Colors.black87,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IconButton(
          icon: const Icon(
            Icons.delete,
            color: Colors.red,
          ),
          onPressed: widget.onDeleteQuiz,
        ),
      ],
    );
  }
}
