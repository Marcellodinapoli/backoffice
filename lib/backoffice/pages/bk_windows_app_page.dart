import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/bk_credit_calc_desktop_service.dart';

/// BackOffice: pubblicazione app Windows CreditCalc e aggiornamenti OTA.
class BkWindowsAppPage extends StatefulWidget {
  const BkWindowsAppPage({super.key});

  @override
  State<BkWindowsAppPage> createState() => _BkWindowsAppPageState();
}

class _BkWindowsAppPageState extends State<BkWindowsAppPage> {
  final _versionCtrl = TextEditingController(text: '1.0.0');
  final _urlCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _enabled = true;
  bool _loading = false;
  bool _uploading = false;
  double _uploadProgress = 0;
  bool _hydratedFromFirestore = false;
  Timestamp? _lastUpdatedAt;

  @override
  void initState() {
    super.initState();
    _loadConfigOnce();
  }

  Future<void> _loadConfigOnce() async {
    try {
      final data = await BkCreditCalcDesktopService.loadConfig();
      if (!mounted || data == null) return;
      setState(() {
        _applyConfig(data);
        _hydratedFromFirestore = true;
        _lastUpdatedAt = data['updatedAt'] as Timestamp?;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _versionCtrl.dispose();
    _urlCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _applyConfig(Map<String, dynamic>? data) {
    if (data == null) return;
    _enabled = data['enabled'] as bool? ?? true;
    _versionCtrl.text = (data['version'] ?? '1.0.0').toString();
    _urlCtrl.text = (data['windowsDownloadUrl'] ?? '').toString();
    _notesCtrl.text = (data['releaseNotes'] ?? '').toString();
  }

  Future<void> _saveConfig({bool showSnack = true}) async {
    final version = _versionCtrl.text.trim();
    final url = _urlCtrl.text.trim();
    if (version.isEmpty) {
      _snack('Inserisci la versione.', isError: true);
      return;
    }
    if (url.isEmpty) {
      _snack('Carica uno ZIP o incolla URL di download.', isError: true);
      return;
    }

    setState(() => _loading = true);
    try {
      await BkCreditCalcDesktopService.saveConfig(
        enabled: _enabled,
        version: version,
        windowsDownloadUrl: url,
        releaseNotes: _notesCtrl.text,
      );
      if (showSnack && mounted) {
        _snack('Configurazione salvata su Firestore.');
      }
    } catch (e) {
      if (mounted) _snack('Errore salvataggio: $e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _uploadZip() async {
    final version = _versionCtrl.text.trim();
    if (version.isEmpty) {
      _snack('Inserisci la versione prima di caricare.', isError: true);
      return;
    }

    setState(() {
      _uploading = true;
      _uploadProgress = 0;
    });

    try {
      final url = await BkCreditCalcDesktopService.uploadReleaseZip(
        version: version,
        onProgress: (p) {
          if (mounted) setState(() => _uploadProgress = p);
        },
      );
      _urlCtrl.text = url;
      await _saveConfig(showSnack: false);
      if (mounted) {
        _snack('ZIP caricato e configurazione aggiornata.');
      }
    } catch (e) {
      if (mounted) _snack('Upload fallito: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
          _uploadProgress = 0;
        });
      }
    }
  }

  void _snack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: BkCreditCalcDesktopService.watchConfig(),
      builder: (context, snap) {
        if (snap.hasData &&
            snap.data!.exists &&
            !_hydratedFromFirestore &&
            !_uploading &&
            !_loading) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || _hydratedFromFirestore) return;
            setState(() {
              _applyConfig(snap.data!.data());
              _hydratedFromFirestore = true;
              _lastUpdatedAt = snap.data!.data()?['updatedAt'] as Timestamp?;
            });
          });
        }
        if (snap.hasData && snap.data!.exists) {
          _lastUpdatedAt = snap.data!.data()?['updatedAt'] as Timestamp?;
        }

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'App Windows — CreditCalc',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Documento Firestore: ${BkCreditCalcDesktopService.firestorePath}',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Download abilitato'),
                        subtitle: const Text(
                          'Se disattivato, l app desktop non propone aggiornamenti.',
                        ),
                        value: _enabled,
                        onChanged: _loading || _uploading
                            ? null
                            : (v) => setState(() => _enabled = v),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _versionCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Versione release',
                          hintText: 'es. 1.0.1',
                          border: OutlineInputBorder(),
                          helperText:
                              'Deve essere maggiore della versione installata dagli utenti.',
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _notesCtrl,
                        minLines: 2,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Note di rilascio (opzionale)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _urlCtrl,
                        decoration: InputDecoration(
                          labelText: 'URL download Windows (ZIP)',
                          border: const OutlineInputBorder(),
                          suffixIcon: _urlCtrl.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Copia URL',
                                  icon: const Icon(Icons.copy),
                                  onPressed: () {
                                    Clipboard.setData(
                                      ClipboardData(text: _urlCtrl.text),
                                    );
                                    _snack('URL copiato.');
                                  },
                                ),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      if (_uploading) ...[
                        const SizedBox(height: 16),
                        LinearProgressIndicator(value: _uploadProgress),
                        const SizedBox(height: 8),
                        Text(
                          'Upload ${(_uploadProgress * 100).toStringAsFixed(0)}%…',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                      const SizedBox(height: 24),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          FilledButton.icon(
                            onPressed: _uploading || _loading ? null : _uploadZip,
                            icon: const Icon(Icons.upload_file),
                            label: const Text('Carica ZIP su Firebase'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _uploading || _loading
                                ? null
                                : () => _saveConfig(),
                            icon: _loading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.save),
                            label: const Text('Salva configurazione'),
                          ),
                          if (_urlCtrl.text.trim().isNotEmpty)
                            OutlinedButton.icon(
                              onPressed: () async {
                                final uri = Uri.tryParse(_urlCtrl.text.trim());
                                if (uri == null) return;
                                await launchUrl(
                                  uri,
                                  mode: LaunchMode.externalApplication,
                                );
                              },
                              icon: const Icon(Icons.open_in_new),
                              label: const Text('Apri URL'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Procedura release',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '1. Nel repo creditcalc-tool esegui scripts/build_windows_release.ps1\n'
                        '2. Ottieni dist/CreditCalc-<versione>-win64.zip\n'
                        '3. Imposta la versione qui sopra e clicca «Carica ZIP su Firebase»\n'
                        '4. Verifica URL e note, poi «Salva configurazione»\n'
                        '5. Gli utenti con app più vecchia vedranno badge e banner aggiornamento',
                        style: TextStyle(fontSize: 14, height: 1.5),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Storage: gs://…/${BkCreditCalcDesktopService.storageFolder}/',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade800,
                          fontFamily: 'Consolas',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_lastUpdatedAt != null) ...[
                const SizedBox(height: 16),
                Text(
                  'Ultimo aggiornamento config: ${_formatTimestamp(_lastUpdatedAt)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  String _formatTimestamp(dynamic value) {
    if (value is Timestamp) {
      final d = value.toDate();
      return '${d.day.toString().padLeft(2, '0')}/'
          '${d.month.toString().padLeft(2, '0')}/'
          '${d.year} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
    }
    return value.toString();
  }
}
