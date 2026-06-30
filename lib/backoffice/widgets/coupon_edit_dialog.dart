import 'package:flutter/material.dart';

import '../services/coupon_admin_service.dart';

class CouponEditDialog extends StatefulWidget {
  final CouponRecord record;

  const CouponEditDialog({super.key, required this.record});

  static Future<bool?> show(BuildContext context, CouponRecord record) {
    return showDialog<bool>(
      context: context,
      builder: (_) => CouponEditDialog(record: record),
    );
  }

  @override
  State<CouponEditDialog> createState() => _CouponEditDialogState();
}

class _CouponEditDialogState extends State<CouponEditDialog> {
  late final TextEditingController _labelCtrl;
  late final TextEditingController _maxUsesCtrl;
  DateTime? _expiresAt;
  DateTime? _benefitExpiresAt;
  String? _restrictedPlan;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final r = widget.record;
    _labelCtrl = TextEditingController(text: r.label ?? '');
    _maxUsesCtrl = TextEditingController(
      text: r.maxUses?.toString() ?? '',
    );
    _expiresAt = r.expiresAt;
    _benefitExpiresAt = r.benefitExpiresAt;
    _restrictedPlan = r.plan;
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _maxUsesCtrl.dispose();
    super.dispose();
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _pickDate({required bool benefit}) async {
    final now = DateTime.now();
    final initial = benefit
        ? (_benefitExpiresAt ?? now.add(const Duration(days: 30)))
        : (_expiresAt ?? now.add(const Duration(days: 365)));
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now,
      lastDate: now.add(const Duration(days: 3650)),
      helpText: benefit
          ? 'Scadenza effetto piano/limiti *'
          : 'Ultimo giorno per inserire il codice',
    );
    if (date == null || !mounted) return;
    setState(() {
      if (benefit) {
        _benefitExpiresAt = date;
      } else {
        _expiresAt = date;
      }
    });
  }

  Future<void> _save() async {
    int? maxUses;
    final maxRaw = _maxUsesCtrl.text.trim();
    if (maxRaw.isNotEmpty) {
      maxUses = int.tryParse(maxRaw);
      if (maxUses == null || maxUses < 1) {
        setState(() => _error = 'Utilizzi massimi non valido.');
        return;
      }
    }
    if (_benefitExpiresAt == null) {
      setState(() => _error = 'Inserisci la scadenza effetto piano/limiti.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await CouponAdminService.updateCoupon(
        code: widget.record.code,
        label: _labelCtrl.text.trim(),
        maxUses: maxUses,
        clearMaxUses: maxRaw.isEmpty,
        expiresAt: _expiresAt,
        clearExpiresAt: _expiresAt == null,
        benefitExpiresAt: _benefitExpiresAt!,
        restrictedPlan: _restrictedPlan,
        clearPlan: _restrictedPlan == null,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e
            .toString()
            .replaceFirst('StateError: ', '')
            .replaceFirst('ArgumentError: ', '');
      });
    }
  }

  Future<void> _delete() async {
    final used = widget.record.usedCount;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Elimina coupon'),
        content: Text(
          used > 0
              ? 'Il coupon ${widget.record.code} è stato usato $used volte. '
                  'Eliminarlo non revoca i benefici già applicati agli utenti. '
                  'Continuare?'
              : 'Eliminare definitivamente il coupon ${widget.record.code}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await CouponAdminService.deleteCoupon(widget.record.code);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Impossibile eliminare il coupon.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Modifica ${widget.record.code}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _labelCtrl,
              decoration: const InputDecoration(
                labelText: 'Nota interna',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _maxUsesCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Utilizzi massimi (vuoto = illimitati)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String?>(
              value: _restrictedPlan,
              decoration: const InputDecoration(
                labelText: 'Piano vincolato',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: null, child: Text('Qualsiasi piano')),
                DropdownMenuItem(value: 'free', child: Text('Solo Gratis')),
                DropdownMenuItem(value: 'plus', child: Text('Solo Plus')),
                DropdownMenuItem(
                  value: 'enterprise',
                  child: Text('Solo Enterprise'),
                ),
              ],
              onChanged: _saving ? null : (v) => setState(() => _restrictedPlan = v),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _saving ? null : () => _pickDate(benefit: true),
              icon: const Icon(Icons.event_available_outlined, size: 18),
              label: Text(
                _benefitExpiresAt == null
                    ? 'Scadenza effetto *'
                    : 'Effetto fino al: ${_formatDate(_benefitExpiresAt!)}',
              ),
            ),
            OutlinedButton.icon(
              onPressed: _saving ? null : () => _pickDate(benefit: false),
              icon: const Icon(Icons.event_outlined, size: 18),
              label: Text(
                _expiresAt == null
                    ? 'Scadenza utilizzo codice'
                    : 'Codice fino al: ${_formatDate(_expiresAt!)}',
              ),
            ),
            if (_expiresAt != null)
              TextButton(
                onPressed: _saving ? null : () => setState(() => _expiresAt = null),
                child: const Text('Rimuovi scadenza utilizzo codice'),
              ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Colors.red.shade700, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : _delete,
          child: Text(
            'Elimina',
            style: TextStyle(color: Colors.red.shade700),
          ),
        ),
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Salva'),
        ),
      ],
    );
  }
}
