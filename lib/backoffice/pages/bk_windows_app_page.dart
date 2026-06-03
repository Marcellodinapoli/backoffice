import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
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
  int _releasesRefreshKey = 0;

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
      _snack('Carica un installer .exe o incolla URL di download.', isError: true);
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

  Future<void> _uploadSetupExe() async {
    final version = _versionCtrl.text.trim();
    if (version.isEmpty) {
      _snack('Inserisci la versione prima di caricare.', isError: true);
      return;
    }

    final notes = _notesCtrl.text;
    final enabled = _enabled;

    setState(() {
      _uploading = true;
      _uploadProgress = 0;
    });

    try {
      final uploaded = await BkCreditCalcDesktopService.uploadReleaseInstaller(
        version: version,
        onProgress: (p) {
          if (mounted) setState(() => _uploadProgress = p);
        },
      );
      await BkCreditCalcDesktopService.saveConfig(
        enabled: enabled,
        version: uploaded.version,
        windowsDownloadUrl: uploaded.downloadUrl,
        windowsInstallerUrl: uploaded.downloadUrl,
        releaseNotes: notes,
      );
      if (mounted) {
        setState(() {
          _releasesRefreshKey++;
          _versionCtrl.clear();
          _notesCtrl.clear();
          _urlCtrl.clear();
        });
        _snack(
          'Release v${uploaded.version} attiva: ${uploaded.fileName}',
        );
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        _snack(
          'Upload rifiutato (${e.code}): ${e.message ?? e.plugin}',
          isError: true,
        );
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

  Future<void> _activateRelease(DesktopReleaseZip zip) async {
    final version = BkCreditCalcDesktopService.versionFromZipName(zip.name);
    if (version == null) {
      _snack('Nome file non riconosciuto: ${zip.name}', isError: true);
      return;
    }

    setState(() => _loading = true);
    try {
      final isSetup =
          BkCreditCalcDesktopService.isInstallerFileName(zip.name);
      await BkCreditCalcDesktopService.saveConfig(
        enabled: _enabled,
        version: version,
        windowsDownloadUrl: zip.downloadUrl,
        windowsInstallerUrl: isSetup ? zip.downloadUrl : '',
        releaseNotes: _notesCtrl.text,
      );
      if (mounted) {
        setState(() {
          _releasesRefreshKey++;
          _versionCtrl.clear();
          _notesCtrl.clear();
          _urlCtrl.clear();
        });
        _snack('Release attiva su Planet: ${zip.name}');
      }
    } catch (e) {
      if (mounted) _snack('Attivazione fallita: $e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _planetUrlFromConfig(Map<String, dynamic> config) {
    final installer = (config['windowsInstallerUrl'] ?? '').toString().trim();
    if (installer.isNotEmpty) return installer;
    return (config['windowsDownloadUrl'] ?? '').toString().trim();
  }

  bool _isActiveRelease(DesktopReleaseZip zip, Map<String, dynamic>? config) {
    if (config == null) return false;
    final activeUrl = _planetUrlFromConfig(config);
    if (activeUrl.isNotEmpty && zip.downloadUrl == activeUrl) return true;

    final activeVer = (config['version'] ?? '').toString().trim();
    final ver = BkCreditCalcDesktopService.versionFromZipName(zip.name);
    if (ver == null || ver != activeVer) return false;

    final wantsSetup = activeUrl.toLowerCase().contains('-setup.exe');
    final isSetup =
        BkCreditCalcDesktopService.isInstallerFileName(zip.name);
    return wantsSetup ? isSetup : zip.name.toLowerCase().endsWith('.zip');
  }

  String? _expectedSetupName() {
    final v = _versionCtrl.text.trim();
    if (v.isEmpty) return null;
    try {
      return BkCreditCalcDesktopService.setupObjectName(v);
    } catch (_) {
      return null;
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

        final firestoreConfig = snap.data?.data();

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
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: 'Versione release',
                          hintText: 'es. 1.0.1',
                          border: const OutlineInputBorder(),
                          helperText:
                              'Deve essere maggiore della versione installata dagli utenti.',
                          suffixText: _expectedSetupName(),
                        ),
                      ),
                      if (_expectedSetupName() != null) ...[
                        const SizedBox(height: 8),
                        SelectableText(
                          'File da caricare: ${_expectedSetupName()}\n'
                          'Build locale: ${BkCreditCalcDesktopService.localSetupPathHint(_versionCtrl.text.trim())}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                            fontFamily: 'Consolas',
                          ),
                        ),
                      ],
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
                          labelText: 'URL download Windows (Setup.exe)',
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
                            onPressed:
                                _uploading || _loading ? null : _uploadSetupExe,
                            icon: const Icon(Icons.install_desktop),
                            label: const Text('Carica Setup.exe'),
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
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Installer su Storage',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Aggiorna elenco',
                            onPressed: () =>
                                setState(() => _releasesRefreshKey++),
                            icon: const Icon(Icons.refresh),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Cartella: ${BkCreditCalcDesktopService.storageFolder}/',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                          fontFamily: 'Consolas',
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (firestoreConfig != null) ...[
                        Builder(
                          builder: (context) {
                            final planetFile =
                                BkCreditCalcDesktopService.activeFileNameFromConfig(
                              firestoreConfig,
                            );
                            if (planetFile == null) {
                              return const SizedBox.shrink();
                            }
                            final isSetup = planetFile
                                .toLowerCase()
                                .contains('-setup.exe');
                            return Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSetup
                                    ? Colors.green.shade50
                                    : Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSetup
                                      ? Colors.green.shade200
                                      : Colors.orange.shade200,
                                ),
                              ),
                              child: Text(
                                isSetup
                                    ? 'Planet scarica ora: $planetFile'
                                    : 'ATTENZIONE — Planet scarica ancora lo ZIP:\n$planetFile\n'
                                        'Clicca Usa su CreditCalc-*-Setup.exe qui sotto.',
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.4,
                                  color: isSetup
                                      ? Colors.green.shade900
                                      : Colors.orange.shade900,
                                  fontWeight: isSetup
                                      ? FontWeight.w500
                                      : FontWeight.w600,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                      FutureBuilder<List<DesktopReleaseZip>>(
                        key: ValueKey(_releasesRefreshKey),
                        future: BkCreditCalcDesktopService.listReleaseZips(),
                        builder: (context, snap) {
                          if (snap.connectionState ==
                              ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }
                          if (snap.hasError) {
                            return Text(
                              'Impossibile leggere Storage: ${snap.error}',
                              style: TextStyle(color: Colors.red.shade700),
                            );
                          }
                          final installers = (snap.data ?? [])
                              .where(
                                (f) => BkCreditCalcDesktopService
                                    .isInstallerFileName(f.name),
                              )
                              .toList();
                          if (installers.isEmpty) {
                            return const Text(
                              'Nessun Setup.exe in Storage. Esegui la build e carica CreditCalc-*-Setup.exe.',
                            );
                          }
                          return Column(
                            children: installers.map((zip) {
                              final sizeMb =
                                  (zip.sizeBytes / (1024 * 1024))
                                      .toStringAsFixed(2);
                              final ver = BkCreditCalcDesktopService
                                  .versionFromZipName(zip.name);
                              final isSetup = BkCreditCalcDesktopService
                                  .isInstallerFileName(zip.name);
                              final isActive =
                                  _isActiveRelease(zip, firestoreConfig);
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(
                                  isSetup
                                      ? Icons.install_desktop
                                      : Icons.folder_zip,
                                  size: 22,
                                  color: isActive ? Colors.green.shade700 : null,
                                ),
                                title: Row(
                                  children: [
                                    Expanded(child: Text(zip.name)),
                                    if (isActive)
                                      Container(
                                        margin: const EdgeInsets.only(left: 8),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade100,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          'ATTIVA',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green.shade800,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                subtitle: Text(
                                  '${ver ?? "?"} · $sizeMb MB · '
                                  '${_formatTimestamp(zip.updated)}',
                                ),
                                trailing: Wrap(
                                  spacing: 4,
                                  children: [
                                    IconButton(
                                      tooltip: 'Copia URL',
                                      icon: const Icon(Icons.copy, size: 20),
                                      onPressed: () {
                                        Clipboard.setData(
                                          ClipboardData(
                                            text: zip.downloadUrl,
                                          ),
                                        );
                                        _snack('URL copiato.');
                                      },
                                    ),
                                    FilledButton.tonal(
                                      onPressed: isActive ||
                                              _loading ||
                                              _uploading
                                          ? null
                                          : () => _activateRelease(zip),
                                      child: Text(
                                        isActive ? 'In uso' : 'Usa',
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          );
                        },
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
                        '1. Installa Inno Setup 6 (una tantum): https://jrsoftware.org/isdl.php\n'
                        '2. Aumenta version in creditcalc-tool/credit_calc/pubspec.yaml\n'
                        '3. Build: powershell -File scripts/build_creditcalc_setup.ps1\n'
                        '4. Carica SOLO dist/CreditCalc-<versione>-Setup.exe su Firebase\n'
                        '5. L utente scarica il Setup.exe e installa (come OBS)\n'
                        '6. Non usare file ZIP: Planet riceve solo il Setup.exe',
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
    if (value is DateTime) {
      final d = value;
      return '${d.day.toString().padLeft(2, '0')}/'
          '${d.month.toString().padLeft(2, '0')}/'
          '${d.year} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
    }
    if (value == null) return '—';
    return value.toString();
  }
}
