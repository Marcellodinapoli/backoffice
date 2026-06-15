import 'package:flutter/material.dart';

/// Motore AI roleplay configurabile per simulazione (Firestore `aiProvider`).
abstract final class BkRoleplayAiProvider {
  static const hetzner = 'hetzner';
  static const gpt = 'gpt';

  static String read(Map<String, dynamic> data) {
    final value = (data['aiProvider'] ?? hetzner).toString().toLowerCase().trim();
    return value == gpt ? gpt : hetzner;
  }

  static String label(String provider) =>
      provider == gpt ? 'GPT-4o mini' : 'Hetzner';

  static Widget selector({
    required String current,
    required ValueChanged<String> onChanged,
  }) {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(
          value: hetzner,
          label: Text('Hetzner'),
          icon: Icon(Icons.dns_outlined, size: 18),
        ),
        ButtonSegment(
          value: gpt,
          label: Text('GPT'),
          icon: Icon(Icons.auto_awesome_outlined, size: 18),
        ),
      ],
      selected: {current},
      onSelectionChanged: (selection) => onChanged(selection.first),
      showSelectedIcon: false,
    );
  }
}
