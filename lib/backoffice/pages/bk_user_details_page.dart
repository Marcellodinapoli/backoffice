// -----------------------------------------------------------------------------
// IMPORT
// -----------------------------------------------------------------------------
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:backoffice/backoffice/widgets/bk_impaginazione_secondaria.dart';

// -----------------------------------------------------------------------------
// PAGE
// -----------------------------------------------------------------------------
class BkUserDetailsPage extends StatefulWidget {
  final String? userId;

  const BkUserDetailsPage({super.key, this.userId});

  @override
  State<BkUserDetailsPage> createState() => _BkUserDetailsPageState();
}

// -----------------------------------------------------------------------------
// STATE
// -----------------------------------------------------------------------------
class _BkUserDetailsPageState extends State<BkUserDetailsPage> {

  // ---------------------------------------------------------------------------
  // UI HELPERS
  // ---------------------------------------------------------------------------

  Color _statusColor(String status) {
    switch (status) {
      case "active":
        return Colors.green;
      case "blocked":
        return Colors.red;
      case "standby":
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  // ---------------------------------------------------------------------------
  // SERVICES / ACTIONS
  // ---------------------------------------------------------------------------

  Future<void> _updateField(String field, dynamic value) async {
    await FirebaseFirestore.instance
        .collection("users")
        .doc(widget.userId)
        .update({field: value});
  }

  Future<void> _toggleType(String currentType) async {
    final newType = currentType == "work" ? "public" : "work";
    await _updateField("type", newType);
  }

  Future<void> _blockUserWithReason(BuildContext context) async {
    final controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Blocca utente"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: "Motivazione blocco",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Annulla"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final reason = controller.text.trim();
              if (reason.isEmpty) return;

              await FirebaseFirestore.instance
                  .collection("users")
                  .doc(widget.userId)
                  .update({
                "status": "blocked",
                "blockedReason": reason,
                "blockedAt": FieldValue.serverTimestamp(),
              });

              if (!context.mounted) return;
              Navigator.pop(context);
            },
            child: const Text("Conferma"),
          ),
        ],
      ),
    );
  }

  Future<void> _standbyUserWithReason(BuildContext context) async {
    final controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Utente in standby"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: "Motivazione standby",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Annulla"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final reason = controller.text.trim();
              if (reason.isEmpty) return;

              await FirebaseFirestore.instance
                  .collection("users")
                  .doc(widget.userId)
                  .update({
                "status": "standby",
                "standbyReason": reason,
                "standbyAt": FieldValue.serverTimestamp(),
              });

              if (!context.mounted) return;
              Navigator.pop(context);
            },
            child: const Text("Conferma"),
          ),
        ],
      ),
    );
  }

// ---------------------------------------------------------------------------
// BUILD
// ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return ImpaginazioneSecondariaBk(
      pageTitle: "Dettagli Utente",
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (widget.userId == null) {
      return const Center(
        child: Text(
          "⚠️ Nessun utente selezionato",
          style: TextStyle(fontSize: 16, color: Colors.black54),
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .snapshots(),
      builder: (context, snapshot) {

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(
            child: Text(
              "❌ Utente non trovato",
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>?;

        final name = data?['name'] ?? 'Nome non disponibile';
        final email = data?['email'] ?? 'Email non disponibile';
        final type = data?['type'] ?? 'Non specificato';
        final status = data?['status'] ?? 'active';
        final blockedReason = data?['blockedReason'];
        final standbyReason = data?['standbyReason'];

        final createdAt =
            data?['createdAt']?.toDate()?.toString() ?? 'Data non disponibile';

        final workRole = data?['workRole'];
        final companyId = data?['companyId'];
        final lastLogin =
            data?['lastLoginAt']?.toDate()?.toString() ?? 'Non disponibile';

        // ✅ NUOVO: date blocco / standby
        final blockedAt = data?['blockedAt'];
        final standbyAt = data?['standbyAt'];

        final blockedDate = blockedAt != null
            ? (blockedAt as Timestamp).toDate().toString()
            : null;

        final standbyDate = standbyAt != null
            ? (standbyAt as Timestamp).toDate().toString()
            : null;

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          children: [

            Card(
              elevation: 1.5,
              color: const Color(0xFFF5F5F5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    Row(
                      children: [
                        Icon(Icons.circle,
                            color: _statusColor(status),
                            size: 12),
                        const SizedBox(width: 10),
                        const Icon(Icons.person_outline,
                            color: Colors.blueGrey,
                            size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    Text("Email: $email"),
                    Text("Tipo: $type"),
                    Text("Stato: $status"),
                    Text("Registrato il: $createdAt"),
                    Text("Ultimo accesso: $lastLogin"),

                    // ✅ BLOCCO INFO
                    if (status == "blocked" && blockedDate != null)
                      Text(
                        "Bloccato il: $blockedDate",
                        style: const TextStyle(color: Colors.red),
                      ),

                    if (status == "blocked" &&
                        blockedReason != null &&
                        blockedReason.toString().isNotEmpty)
                      Text(
                        "Motivo blocco: $blockedReason",
                        style: const TextStyle(color: Colors.red),
                      ),

                    // ✅ STANDBY INFO
                    if (status == "standby" && standbyDate != null)
                      Text(
                        "Standby dal: $standbyDate",
                        style: const TextStyle(color: Colors.orange),
                      ),

                    if (status == "standby" &&
                        standbyReason != null &&
                        standbyReason.toString().isNotEmpty)
                      Text(
                        "Motivo standby: $standbyReason",
                        style: const TextStyle(color: Colors.orange),
                      ),

                    if (workRole != null)
                      Text("Ruolo aziendale: $workRole"),

                    if (companyId != null)
                      FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection("companies")
                            .doc(companyId)
                            .get(),
                        builder: (context, companySnap) {
                          if (!companySnap.hasData || !companySnap.data!.exists) {
                            return Text("Azienda collegata: $companyId");
                          }
                          final companyData =
                          companySnap.data!.data() as Map<String, dynamic>?;
                          final companyName =
                              companyData?['name'] ?? companyId;
                          return Text("Azienda collegata: $companyName");
                        },
                      ),

                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 18),

                    const Text(
                      "Azioni amministratore",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 16),

                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [

                        _actionButton(
                          label: "Blocca utente",
                          color: Colors.red,
                          onTap: () => _blockUserWithReason(context),
                        ),

                        _actionButton(
                          label: "Standby",
                          color: Colors.orange,
                          onTap: () => _standbyUserWithReason(context),
                        ),

                        _actionButton(
                          label:
                          "Cambia tipo (${type == "work" ? "public" : "work"})",
                          color: const Color(0xFF1565C0),
                          onTap: () async {
                            await _toggleType(type);
                          },
                        ),

                        if (status != "active")
                          _actionButton(
                            label: "Attiva utente",
                            color: Colors.green,
                            onTap: () async {
                              await _updateField("status", "active");
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),

            const Center(
              child: Text(
                "📊 Altri dati o progressi non disponibili",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        );
      },
    );
  }
  Widget _actionButton({
    required String label,
    required Color color,
    Color textColor = Colors.white,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 44,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: textColor,
          shape: const StadiumBorder(),
          elevation: 0,
        ),
        onPressed: onTap,
        child: Text(label),
      ),
    );
  }

}