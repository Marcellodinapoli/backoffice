import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../widgets/settings_cleanup_button.dart';

class BkSettingsPage extends StatefulWidget {
  const BkSettingsPage({super.key});

  @override
  State<BkSettingsPage> createState() => _BkSettingsPageState();
}

class _BkSettingsPageState extends State<BkSettingsPage> {
  bool _savingMaintenance = false;

  static const _sections = [
    'Tutto',
    'CreditForm',
    'CreditJob',
    'CreditCalc',
    'Area riservata',
  ];

  static DocumentReference<Map<String, dynamic>> get _maintenanceDoc =>
      FirebaseFirestore.instance.collection('settings').doc('maintenance');

  static DocumentReference<Map<String, dynamic>> get _notificationsDoc =>
      FirebaseFirestore.instance.collection('settings').doc('notifications');

  static Stream<DocumentSnapshot<Map<String, dynamic>>> _watchMaintenance() =>
      _maintenanceDoc.snapshots();

  static Stream<DocumentSnapshot<Map<String, dynamic>>> _watchNotifications() =>
      _notificationsDoc.snapshots();

  bool _readEnabled(Map<String, dynamic>? data) {
    if (data == null) return false;
    final raw = data['enabled'];
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    if (raw is String) {
      final normalized = raw.trim().toLowerCase();
      return normalized == 'true' || normalized == '1';
    }
    return false;
  }

  String _readSection(Map<String, dynamic>? data) {
    final section = data?['section']?.toString().trim();
    if (section == null || section.isEmpty) return 'Tutto';
    return section;
  }

  Future<void> _saveMaintenanceSettings({
    required bool enabled,
    required String section,
  }) async {
    setState(() => _savingMaintenance = true);
    try {
      await _maintenanceDoc.set({
        'section': section,
        'enabled': enabled,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': 'backoffice',
      }, SetOptions(merge: true));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enabled
                ? 'Manutenzione attiva su: $section'
                : 'Manutenzione disattivata',
          ),
        ),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text(
            'Salvataggio manutenzione rifiutato (${e.code}). '
            'Verifica di essere admin Firebase.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text('Errore salvataggio manutenzione: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _savingMaintenance = false);
    }
  }

  Future<void> _saveNotificationsEnabled(bool enabled) async {
    try {
      await _notificationsDoc.set({
        'enabled': enabled,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': 'backoffice',
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text('Salvataggio notifiche rifiutato (${e.code}).'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text('Errore salvataggio notifiche: $e'),
        ),
      );
    }
  }

  Widget _buildMaintenanceCard(Map<String, dynamic>? data) {
    final maintenanceMode = _readEnabled(data);
    final selectedSection = _readSection(data);

    return Card(
      color: const Color(0xFFF5F5F5),
      child: Column(
        children: [
          ListTile(
            title: const Text('Seleziona sezione da bloccare'),
            subtitle: const Text(
              'Applica la manutenzione solo a questa sezione o pagina',
            ),
            trailing: DropdownButton<String>(
              value: _sections.contains(selectedSection) ? selectedSection : 'Tutto',
              items: _sections
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
              onChanged: _savingMaintenance
                  ? null
                  : (value) {
                final section = value ?? 'Tutto';
                _saveMaintenanceSettings(
                  enabled: maintenanceMode,
                  section: section,
                );
              },
            ),
          ),
          const Divider(height: 1),
          SwitchListTile(
            title: const Text('Modalità manutenzione'),
            subtitle: Text(
              'Blocca temporaneamente l\'accesso a: $selectedSection\n'
              'Salvato su Firestore: Planet e BackOffice app si aggiornano in tempo reale.',
            ),
            value: maintenanceMode,
            onChanged: _savingMaintenance
                ? null
                : (value) {
              _saveMaintenanceSettings(
                enabled: value,
                section: selectedSection,
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _watchMaintenance(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting &&
                !snap.hasData) {
              return const Card(
                color: Color(0xFFF5F5F5),
                child: ListTile(
                  title: Text('Caricamento manutenzione…'),
                  trailing: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }

            return _buildMaintenanceCard(snap.data?.data());
          },
        ),
        const SizedBox(height: 12),
        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _watchNotifications(),
          builder: (context, snap) {
            final notificationsEnabled = _readEnabled(snap.data?.data());
            return Card(
              color: const Color(0xFFF5F5F5),
              child: SwitchListTile(
                title: const Text('Notifiche attive'),
                subtitle: const Text(
                  'Abilita o disabilita le notifiche di sistema (salvato su Firestore)',
                ),
                value: notificationsEnabled,
                onChanged: (value) => _saveNotificationsEnabled(value),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        Card(
          color: const Color(0xFFF5F5F5),
          child: ListTile(
            title: const Text('Pulizia database'),
            subtitle: const Text(
              'Rimuove pendingLogins scaduti e collezioni test/debug',
            ),
            trailing: const SettingsCleanupButton(),
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
