import 'package:flutter/material.dart';

import '../models/cleanup_result.dart';
import '../services/database_cleanup_service.dart';

class SettingsCleanupButton extends StatefulWidget {
  const SettingsCleanupButton({super.key});

  @override
  State<SettingsCleanupButton> createState() => _SettingsCleanupButtonState();
}

class _SettingsCleanupButtonState extends State<SettingsCleanupButton> {
  bool _running = false;

  Future<void> _runCleanup() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Pulizia database'),
        content: const Text(DatabaseCleanupService.confirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Pulisci'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _running = true);

    CleanupResult result;
    try {
      result = await DatabaseCleanupService.instance.run();
    } catch (e) {
      if (!mounted) return;
      setState(() => _running = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('Errore durante la pulizia: $e'),
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _running = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: result.hasErrors ? Colors.orange.shade800 : null,
        content: Text(result.summaryMessage()),
        duration: Duration(seconds: result.hasErrors ? 4 : 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_running) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    return ElevatedButton.icon(
      icon: const Icon(Icons.cleaning_services),
      label: const Text('Pulisci tutto'),
      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
      onPressed: _runCleanup,
    );
  }
}
