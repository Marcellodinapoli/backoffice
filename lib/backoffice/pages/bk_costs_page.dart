// lib/backoffice/pages/bk_costs_page.dart
import 'package:flutter/material.dart';

class BkCostsPage extends StatefulWidget {
  const BkCostsPage({super.key});

  @override
  State<BkCostsPage> createState() => _BkCostsPageState();
}

class _BkCostsPageState extends State<BkCostsPage> {
  String selectedMonth = "Gennaio";

  // 🔹 Dati da integrare con Firestore/API
  final Map<String, List<Map<String, dynamic>>> monthlyData = {
    "Gennaio": [],
    "Febbraio": [],
  };

  double _calculateTotal(List<Map<String, dynamic>> data) {
    return data.fold(
      0,
          (sum, item) => sum +
          CostCard.calculateCost(
            service: item["service"],
            reads: item["reads"],
            writes: item["writes"],
            storageMb: item["storageMb"],
            emailsSent: item["emailsSent"],
            storageGb: item["storageGb"],
            trafficGb: item["trafficGb"],
            creditsUsed: item["creditsUsed"],
            minutes: item["minutes"],
            transcriptions: item["transcriptions"],
            analyses: item["analyses"],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = monthlyData[selectedMonth] ?? [];
    final totalCost = _calculateTotal(data);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _kpiBox("Totale", "€${totalCost.toStringAsFixed(2)}"),
              DropdownButton<String>(
                value: selectedMonth,
                items: monthlyData.keys
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (val) => setState(() => selectedMonth = val!),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: data.isEmpty
                ? const Center(
              child: Text(
                "Nessun dato disponibile",
                style: TextStyle(color: Colors.black54),
              ),
            )
                : GridView.count(
              crossAxisCount: 3,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: data
                  .map(
                    (item) => CostCard(
                  service: item["service"],
                  icon: item["icon"],
                  usage: item["usage"],
                  color: item["color"],
                  reads: item["reads"],
                  writes: item["writes"],
                  storageMb: item["storageMb"],
                  emailsSent: item["emailsSent"],
                  storageGb: item["storageGb"],
                  trafficGb: item["trafficGb"],
                  creditsUsed: item["creditsUsed"],
                  minutes: item["minutes"],
                  transcriptions: item["transcriptions"],
                  analyses: item["analyses"],
                ),
              )
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _kpiBox(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 16, color: Colors.blue)),
      ],
    );
  }
}

class CostCard extends StatelessWidget {
  final String service;
  final String usage;
  final Color color;
  final IconData icon;
  final int? reads, writes, storageMb, emailsSent, storageGb, trafficGb,
      creditsUsed, minutes, transcriptions, analyses;

  const CostCard({
    super.key,
    required this.service,
    required this.usage,
    required this.color,
    required this.icon,
    this.reads,
    this.writes,
    this.storageMb,
    this.emailsSent,
    this.storageGb,
    this.trafficGb,
    this.creditsUsed,
    this.minutes,
    this.transcriptions,
    this.analyses,
  });

  static double calculateCost({
    required String service,
    int? reads,
    int? writes,
    int? storageMb,
    int? emailsSent,
    int? storageGb,
    int? trafficGb,
    int? creditsUsed,
    int? minutes,
    int? transcriptions,
    int? analyses,
  }) {
    double cost = 0;
    switch (service) {
      case "Firestore":
        cost += (reads ?? 0) * 0.000001 +
            (writes ?? 0) * 0.000005 +
            ((storageMb ?? 0) / 1024) * 0.18;
        break;
      case "SendGrid":
        cost += (emailsSent ?? 0) * 0.0001;
        break;
      case "Bunny.net":
        cost += (storageGb ?? 0) * 0.01 + (trafficGb ?? 0) * 0.02;
        break;
      case "ElevenLabs":
        cost += (creditsUsed ?? 0) * 0.00012;
        break;
      case "Azure Speech":
        cost += (minutes ?? 0) * 0.005;
        break;
      case "Whisper STT":
        cost += (transcriptions ?? 0) * 0.002;
        break;
      case "AI Valutazione LLM":
        cost += (analyses ?? 0) * 0.01;
        break;
    }
    return cost;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFF5F5F5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              CircleAvatar(
                backgroundColor: color.withOpacity(0.2),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  service,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Text(
              usage.isNotEmpty ? usage : "Nessun dettaglio",
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
            const Spacer(),
            Text(
              "€${calculateCost(
                service: service,
                reads: reads,
                writes: writes,
                storageMb: storageMb,
                emailsSent: emailsSent,
                storageGb: storageGb,
                trafficGb: trafficGb,
                creditsUsed: creditsUsed,
                minutes: minutes,
                transcriptions: transcriptions,
                analyses: analyses,
              ).toStringAsFixed(2)}",
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
