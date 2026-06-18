import 'package:flutter/material.dart';

import '../services/platform_costs_service.dart';

class BkCostsPage extends StatefulWidget {
  const BkCostsPage({super.key});

  @override
  State<BkCostsPage> createState() => _BkCostsPageState();
}

class _BkCostsPageState extends State<BkCostsPage> {
  late String _selectedMonthKey;

  @override
  void initState() {
    super.initState();
    _selectedMonthKey = PlatformCostsService.recentMonthKeys().first;
  }

  Future<void> _editPlatform(
    BuildContext context,
    PlatformMonthCosts costs,
    _PlatformCostKind kind,
  ) async {
    final result = await showDialog<PlatformMonthCosts>(
      context: context,
      builder: (_) => _PlatformCostEditDialog(
        kind: kind,
        initial: costs,
      ),
    );
    if (result == null) return;

    await PlatformCostsService.saveMonth(_selectedMonthKey, result);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Costi aggiornati')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          child: Row(
            children: [
              const Text(
                'Monitoraggio costi piattaforme',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              DropdownButton<String>(
                value: _selectedMonthKey,
                items: PlatformCostsService.recentMonthKeys()
                    .map(
                      (key) => DropdownMenuItem(
                        value: key,
                        child: Text(PlatformCostsService.monthLabel(key)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _selectedMonthKey = value);
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<PlatformMonthCosts>(
            stream: PlatformCostsService.watchMonth(_selectedMonthKey),
            builder: (context, snapshot) {
              final costs = snapshot.data ?? const PlatformMonthCosts();
              final total = costs.total();

              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Card(
                      color: const Color(0xFFE3F2FD),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _kpiBox(
                              'Totale mese',
                              '€${total.toStringAsFixed(2)}',
                            ),
                            _kpiBox(
                              'Mese',
                              PlatformCostsService.monthLabel(_selectedMonthKey),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final crossCount = constraints.maxWidth > 900
                              ? 2
                              : constraints.maxWidth > 600
                                  ? 2
                                  : 1;
                          return GridView.count(
                            crossAxisCount: crossCount,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: crossCount == 1 ? 2.2 : 1.35,
                            children: [
                              _PlatformCostCard(
                                title: 'Bunny.net',
                                icon: Icons.cloud_outlined,
                                color: const Color(0xFFFF6F00),
                                usage:
                                    'Storage: ${costs.bunnyStorageGb.toStringAsFixed(1)} GB\n'
                                    'Traffico: ${costs.bunnyTrafficGb.toStringAsFixed(1)} GB',
                                amount: costs.costBunny(),
                                onEdit: () => _editPlatform(
                                  context,
                                  costs,
                                  _PlatformCostKind.bunny,
                                ),
                              ),
                              _PlatformCostCard(
                                title: 'Hetzner',
                                icon: Icons.dns_outlined,
                                color: const Color(0xFFD32F2F),
                                usage:
                                    'Abbonamento mensile fisso\n'
                                    '€${costs.hetznerMonthlyEur.toStringAsFixed(2)}/mese',
                                amount: costs.costHetzner(),
                                onEdit: () => _editPlatform(
                                  context,
                                  costs,
                                  _PlatformCostKind.hetzner,
                                ),
                              ),
                              _PlatformCostCard(
                                title: 'OpenAI API',
                                icon: Icons.auto_awesome_outlined,
                                color: const Color(0xFF2E7D32),
                                usage:
                                    'Importo da dashboard OpenAI\n'
                                    '(fatturazione reale del mese)',
                                amount: costs.costOpenAi(),
                                onEdit: () => _editPlatform(
                                  context,
                                  costs,
                                  _PlatformCostKind.openai,
                                ),
                              ),
                              _PlatformCostCard(
                                title: 'Firebase',
                                icon: Icons.local_fire_department_outlined,
                                color: const Color(0xFFFF9800),
                                usage:
                                    'Letture: ${_formatInt(costs.firebaseReads)}\n'
                                    'Scritture: ${_formatInt(costs.firebaseWrites)}\n'
                                    'Storage: ${(costs.firebaseStorageMb / 1024).toStringAsFixed(2)} GB',
                                amount: costs.costFirebase(),
                                onEdit: () => _editPlatform(
                                  context,
                                  costs,
                                  _PlatformCostKind.firebase,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _formatInt(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
    return value.toString();
  }

  Widget _kpiBox(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 16, color: Color(0xFF1565C0)),
        ),
      ],
    );
  }
}

enum _PlatformCostKind { bunny, hetzner, openai, firebase }

class _PlatformCostCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final String usage;
  final double amount;
  final VoidCallback onEdit;

  const _PlatformCostCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.usage,
    required this.amount,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFF5F5F5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Modifica metriche',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Text(
                usage,
                style: const TextStyle(fontSize: 13, height: 1.45),
              ),
            ),
            Text(
              '€${amount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlatformCostEditDialog extends StatefulWidget {
  final _PlatformCostKind kind;
  final PlatformMonthCosts initial;

  const _PlatformCostEditDialog({
    required this.kind,
    required this.initial,
  });

  @override
  State<_PlatformCostEditDialog> createState() =>
      _PlatformCostEditDialogState();
}

class _PlatformCostEditDialogState extends State<_PlatformCostEditDialog> {
  late final TextEditingController _c1;
  late final TextEditingController _c2;
  late final TextEditingController _c3;

  @override
  void initState() {
    super.initState();
    final c = widget.initial;
    switch (widget.kind) {
      case _PlatformCostKind.bunny:
        _c1 = TextEditingController(text: c.bunnyStorageGb.toString());
        _c2 = TextEditingController(text: c.bunnyTrafficGb.toString());
        _c3 = TextEditingController();
      case _PlatformCostKind.hetzner:
        _c1 = TextEditingController(text: c.hetznerMonthlyEur.toString());
        _c2 = TextEditingController();
        _c3 = TextEditingController();
      case _PlatformCostKind.openai:
        _c1 = TextEditingController(text: c.openAiAmountEur.toString());
        _c2 = TextEditingController();
        _c3 = TextEditingController();
      case _PlatformCostKind.firebase:
        _c1 = TextEditingController(text: c.firebaseReads.toString());
        _c2 = TextEditingController(text: c.firebaseWrites.toString());
        _c3 = TextEditingController(text: c.firebaseStorageMb.toString());
    }
  }

  @override
  void dispose() {
    _c1.dispose();
    _c2.dispose();
    _c3.dispose();
    super.dispose();
  }

  double _parseDouble(String raw, {double fallback = 0}) {
    return double.tryParse(raw.replaceAll(',', '.')) ?? fallback;
  }

  int _parseInt(String raw) => int.tryParse(raw.trim()) ?? 0;

  PlatformMonthCosts _buildResult() {
    final c = widget.initial;
    switch (widget.kind) {
      case _PlatformCostKind.bunny:
        return PlatformMonthCosts(
          bunnyStorageGb: _parseDouble(_c1.text),
          bunnyTrafficGb: _parseDouble(_c2.text),
          hetznerMonthlyEur: c.hetznerMonthlyEur,
          openAiAmountEur: c.openAiAmountEur,
          firebaseReads: c.firebaseReads,
          firebaseWrites: c.firebaseWrites,
          firebaseStorageMb: c.firebaseStorageMb,
        );
      case _PlatformCostKind.hetzner:
        return PlatformMonthCosts(
          bunnyStorageGb: c.bunnyStorageGb,
          bunnyTrafficGb: c.bunnyTrafficGb,
          hetznerMonthlyEur: _parseDouble(_c1.text, fallback: 17),
          openAiAmountEur: c.openAiAmountEur,
          firebaseReads: c.firebaseReads,
          firebaseWrites: c.firebaseWrites,
          firebaseStorageMb: c.firebaseStorageMb,
        );
      case _PlatformCostKind.openai:
        return PlatformMonthCosts(
          bunnyStorageGb: c.bunnyStorageGb,
          bunnyTrafficGb: c.bunnyTrafficGb,
          hetznerMonthlyEur: c.hetznerMonthlyEur,
          openAiAmountEur: _parseDouble(_c1.text),
          firebaseReads: c.firebaseReads,
          firebaseWrites: c.firebaseWrites,
          firebaseStorageMb: c.firebaseStorageMb,
        );
      case _PlatformCostKind.firebase:
        return PlatformMonthCosts(
          bunnyStorageGb: c.bunnyStorageGb,
          bunnyTrafficGb: c.bunnyTrafficGb,
          hetznerMonthlyEur: c.hetznerMonthlyEur,
          openAiAmountEur: c.openAiAmountEur,
          firebaseReads: _parseInt(_c1.text),
          firebaseWrites: _parseInt(_c2.text),
          firebaseStorageMb: _parseInt(_c3.text),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (widget.kind) {
      _PlatformCostKind.bunny => 'Bunny.net',
      _PlatformCostKind.hetzner => 'Hetzner',
      _PlatformCostKind.openai => 'OpenAI API',
      _PlatformCostKind.firebase => 'Firebase',
    };

    return AlertDialog(
      title: Text('Aggiorna $title'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: switch (widget.kind) {
            _PlatformCostKind.bunny => [
              TextField(
                controller: _c1,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Storage (GB)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _c2,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Traffico (GB)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            _PlatformCostKind.hetzner => [
              TextField(
                controller: _c1,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Abbonamento mensile (€)',
                  border: OutlineInputBorder(),
                  helperText: 'Default: 17,00 €',
                ),
              ),
            ],
            _PlatformCostKind.openai => [
              TextField(
                controller: _c1,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Importo mese (€)',
                  border: OutlineInputBorder(),
                  helperText: 'Copia il totale dalla dashboard OpenAI',
                ),
              ),
            ],
            _PlatformCostKind.firebase => [
              TextField(
                controller: _c1,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Letture documenti',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _c2,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Scritture documenti',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _c3,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Storage (MB)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _buildResult()),
          child: const Text('Salva'),
        ),
      ],
    );
  }
}
