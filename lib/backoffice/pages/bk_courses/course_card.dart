// lib/backoffice/pages/bk_courses/course_card.dart

// -----------------------------------------------------------------------------
// IMPORT
// -----------------------------------------------------------------------------
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// -----------------------------------------------------------------------------
// COURSE CARD
// -----------------------------------------------------------------------------
class CourseCard extends StatelessWidget {
  final DocumentSnapshot doc;
  final VoidCallback onDelete;
  final VoidCallback? onEdit;

  const CourseCard({
    super.key,
    required this.doc,
    required this.onDelete,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;

    final List attachments =
        (data['attachments'] as List?) ?? [];

    final Map<String, dynamic>? quiz =
    data['quiz'] as Map<String, dynamic>?;

    final String? quizFileName =
    quiz?['fileName']?.toString();

    final bool hasQuiz =
        quizFileName != null && quizFileName.isNotEmpty;
    final bool hasAttachments = attachments.isNotEmpty;

    final List contents =
        (data['contents'] as List?) ?? [];

    final Timestamp? createdAt =
    data['createdAt'] as Timestamp?;

    final String createdAtFormatted = createdAt != null
        ? "${createdAt.toDate().day.toString().padLeft(2, '0')}/"
        "${createdAt.toDate().month.toString().padLeft(2, '0')}/"
        "${createdAt.toDate().year}"
        : "-";

    return Card(
      color: const Color(0xFFF5F5F5),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              data['title'] ?? '—',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),

            const SizedBox(height: 4),

            // ---------------------------
            // DATA INSERIMENTO (SUBITO SOTTO TITOLO)
            // ---------------------------
            Text(
              "Inserito il: $createdAtFormatted",
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 8),

            _infoRow("Categoria", data['category']),
            _infoRow("Descrizione", data['description']),

            const SizedBox(height: 6),

            // ---------------------------
            // COSA CONTIENE
            // ---------------------------
            if (contents.isNotEmpty) ...[
              const Text(
                "Cosa contiene:",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ...contents.map((item) => Text("• $item")).toList(),
              const SizedBox(height: 8),
            ],

            // ---------------------------
            // QUIZ INFO
            // ---------------------------
            if (hasQuiz) ...[
              const Text(
                "Quiz:",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text("• $quizFileName"),
              const SizedBox(height: 8),
            ],

            // ---------------------------
            // ALLEGATI LISTA
            // ---------------------------
            if (hasAttachments) ...[
              const Text(
                "Allegati:",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ...attachments.map((item) {
                if (item is Map && item['name'] != null) {
                  return Text("• ${item['name']}");
                }
                return Text("• ${item.toString()}");
              }).toList(),
              const SizedBox(height: 8),
            ],

            _infoRow(
              "Tag",
              (data['tags'] as List?)?.join(', ') ?? '-',
            ),

            const SizedBox(height: 8),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.edit,
                    color: onEdit != null
                        ? Colors.blue
                        : Colors.grey,
                  ),
                  onPressed: onEdit != null
                      ? () => onEdit!()
                      : null,
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete,
                    color: Colors.red,
                  ),
                  onPressed: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UI HELPER
  // ---------------------------------------------------------------------------
  Widget _infoRow(String label, dynamic value) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: "$label: ",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          TextSpan(
            text: value?.toString() ?? '-',
          ),
        ],
      ),
    );
  }
}
