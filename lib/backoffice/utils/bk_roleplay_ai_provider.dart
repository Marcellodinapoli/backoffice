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

  /// Prompt usato da Hetzner (`prompt`) o da GPT (`gptPrompt`).
  static String readPrompt(Map<String, dynamic> data, [String? provider]) {
    final engine = provider ?? read(data);
    if (engine == gpt) {
      return (data['gptPrompt'] ?? '').toString();
    }
    return (data['prompt'] ?? '').toString();
  }

  static String promptFirestoreField(String provider) =>
      provider == gpt ? 'gptPrompt' : 'prompt';

  static String promptFieldLabel(String provider) =>
      provider == gpt ? 'Prompt GPT' : 'Prompt Hetzner';

  static Widget promptEditor({
    required String aiProvider,
    required TextEditingController hetznerPrompt,
    required TextEditingController gptPrompt,
  }) {
    if (aiProvider == gpt) {
      return TextField(
        controller: gptPrompt,
        maxLines: 5,
        decoration: const InputDecoration(
          labelText: 'Prompt GPT',
          hintText: 'Istruzioni dedicate a GPT-4o mini per questa simulazione',
          border: OutlineInputBorder(),
        ),
      );
    }

    return TextField(
      controller: hetznerPrompt,
      maxLines: 5,
      decoration: const InputDecoration(
        labelText: 'Prompt Hetzner',
        border: OutlineInputBorder(),
      ),
    );
  }

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
