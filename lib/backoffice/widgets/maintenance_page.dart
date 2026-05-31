import 'package:flutter/material.dart';

class MaintenancePage extends StatelessWidget {
  final String section;
  final VoidCallback onBack;

  const MaintenancePage({
    super.key,
    required this.section,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        color: const Color(0xFFF5F5F5),
        margin: const EdgeInsets.all(32),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.build, size: 60, color: Colors.orange),
              const SizedBox(height: 16),
              Text(
                "$section in manutenzione",
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Questa sezione è temporaneamente non disponibile.",
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back),
                label: const Text("Torna alla Dashboard"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
