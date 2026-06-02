import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BkSettingsPage extends StatefulWidget {
  const BkSettingsPage({super.key});

  @override
  State<BkSettingsPage> createState() => _BkSettingsPageState();
}

class _BkSettingsPageState extends State<BkSettingsPage> {
  bool maintenanceMode = false;
  bool notificationsEnabled = true;
  String selectedSection = 'Tutto';

  final List<String> sections = [
    'Tutto',
    'CreditForm',
    'CreditJob',
    'CreditCalc',
    'Area riservata',
  ];

  @override
  void initState() {
    super.initState();
    _loadMaintenanceSettings(); // ✅ FIX
  }

  // ✅ CARICAMENTO DA FIRESTORE
  Future<void> _loadMaintenanceSettings() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('maintenance')
          .get();

      if (!doc.exists) return;

      final data = doc.data()!;

      if (!mounted) return;

      setState(() {
        maintenanceMode = data['enabled'] ?? false;
        selectedSection = data['section'] ?? 'Tutto';
      });
    } catch (e) {
      debugPrint("❌ Errore load maintenance: $e");
    }
  }

  // 🔧 Salvataggio manutenzione
  Future<void> _saveMaintenanceSettings() async {
    try {
      await FirebaseFirestore.instance
          .collection('settings')
          .doc('maintenance')
          .set({
        'section': selectedSection,
        'enabled': maintenanceMode,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("❌ Errore salvataggio maintenance: $e");
    }
  }

  // 🧹 Pulizia sicura MIGLIORATA
  Future<void> _cleanupOldData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Conferma pulizia"),
        content: const Text(
          "Verranno eliminati SOLO:\n"
              "- pendingLogins scaduti (>2 minuti)\n"
              "- dati test/debug\n\n"
              "I dati reali NON verranno toccati.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Annulla"),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Pulisci"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final firestore = FirebaseFirestore.instance;
      int deletedCount = 0;

      final now = DateTime.now();
      final limit = now.subtract(const Duration(minutes: 2));

      // ✅ SOLO pendingLogins scaduti
      final pendingSnap = await firestore.collection('pendingLogins').get();
      for (var doc in pendingSnap.docs) {
        final data = doc.data();
        final createdAt = data['createdAt'];

        if (createdAt != null) {
          final date = (createdAt as Timestamp).toDate();
          if (date.isBefore(limit)) {
            await doc.reference.delete();
            deletedCount++;
          }
        }
      }

      // ✅ SOLO collezioni debug/test
      final obsolete = ['temp', 'debug', 'test', 'old_progress', 'backup_old'];
      for (final col in obsolete) {
        final snap = await firestore.collection(col).get();
        for (var doc in snap.docs) {
          await doc.reference.delete();
          deletedCount++;
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.black87,
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            content: Center(
              child: Text(
                '✅ Pulizia completata: $deletedCount elementi rimossi.',
                textAlign: TextAlign.center,
              ),
            ),
            duration: const Duration(seconds: 2),
          ),
        );

    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.redAccent,
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            content: Center(
              child: Text(
                '❌ Errore durante la pulizia: $e',
                textAlign: TextAlign.center,
              ),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: const Color(0xFFF5F5F5),
          child: Column(
            children: [
              ListTile(
                title: const Text('Seleziona sezione da bloccare'),
                subtitle:
                const Text('Applica la manutenzione solo a questa sezione o pagina'),
                trailing: DropdownButton<String>(
                  value: selectedSection,
                  items: sections
                      .map(
                        (s) => DropdownMenuItem(
                      value: s,
                      child: Text(
                        s,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedSection = value ?? 'Tutto';
                    });
                    _saveMaintenanceSettings();
                  },
                ),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text('Modalità manutenzione'),
                subtitle: Text(
                  'Blocca temporaneamente l’accesso a: $selectedSection',
                ),
                value: maintenanceMode,
                onChanged: (value) {
                  setState(() {
                    maintenanceMode = value;
                  });
                  _saveMaintenanceSettings();
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Card(
          color: const Color(0xFFF5F5F5),
          child: SwitchListTile(
            title: const Text('Notifiche attive'),
            subtitle: const Text('Abilita o disabilita le notifiche di sistema'),
            value: notificationsEnabled,
            onChanged: (value) {
              setState(() {
                notificationsEnabled = value;
              });
            },
          ),
        ),
        const SizedBox(height: 12),

        Card(
          color: const Color(0xFFF5F5F5),
          child: ListTile(
            title: const Text('Pulizia database'),
            subtitle: const Text(
                'Rimuove solo dati scaduti e debug (sicuro)'),
            trailing: ElevatedButton.icon(
              icon: const Icon(Icons.cleaning_services),
              label: const Text('Pulisci tutto'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: _cleanupOldData,
            ),
          ),
        ),

        const SizedBox(height: 12),
        const Divider(),
        const Card(
          color: Color(0xFFF5F5F5),
          child: ListTile(
            title: Text('Versione applicazione'),
            subtitle: Text('-'),
          ),
        ),
      ],
    );
  }
}