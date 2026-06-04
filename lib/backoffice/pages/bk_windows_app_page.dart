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
  bool _showManualUrl = false;
  Timestamp? _lastUpdatedAt;
  int _releasesRefreshKey = 0;
  String _cachedActiveVersion = '';
  String _cachedActiveUrl = '';

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
    _cachedActiveVersion = (data['version'] ?? '1.0.0').toString();
    _cachedActiveUrl = _planetUrlFromConfig(data);
    _versionCtrl.text = _cachedActiveVersion;
    _urlCtrl.text = _cachedActiveUrl;
    _notesCtrl.text = (data['releaseNotes'] ?? '').toString();
  }

  String _effectiveVersion() {
    final typed = _versionCtrl.text.trim();
    if (typed.isNotEmpty) return typed;
    return _cachedActiveVersion.trim();
  }

  String _effectiveDownloadUrl([Map<String, dynamic>? firestoreConfig]) {
    final typed = _urlCtrl.text.trim();
    if (typed.isNotEmpty) return typed;
    if (firestoreConfig != null) {
      final fromDb = _planetUrlFromConfig(firestoreConfig);
      if (fromDb.isNotEmpty) return fromDb;
    }
    return _cachedActiveUrl.trim();
  }

  Future<void> _saveConfig({
    bool showSnack = true,
    Map<String, dynamic>? firestoreConfig,
  }) async {
    final version = _effectiveVersion();
    final url = _effectiveDownloadUrl(firestoreConfig);
    if (version.isEmpty) {
      _snack('Inserisci la versione.', isError: true);
      return;
    }
    if (_looksLikeFilePath(version)) {
      _snack(
        'Il campo versione accetta solo numeri (es. 1.0.2).',
        isError: true,
      );
      return;
    }
    if (url.isEmpty) {
      _snack('Carica prima il Setup.exe oppure attiva un file da Storage.', isError: true);
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

  bool _looksLikeFilePath(String value) {
    return value.contains(r'\') ||
        value.contains('/') ||
        value.toLowerCase().contains('.exe');
  }

  Future<void> _uploadSetupExe() async {
    final version = _versionCtrl.text.trim();
    if (version.isEmpty) {
      _snack('Inserisci la versione prima di caricare.', isError: true);
      return;
    }
    if (_looksLikeFilePath(version)) {
      _snack(
        'Inserisci solo il numero versione (es. 1.0.2), non il percorso del file.',
        isError: true,
      );
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
          _cachedActiveVersion = uploaded.version;
          _cachedActiveUrl = uploaded.downloadUrl;
          _versionCtrl.text = uploaded.version;
          _urlCtrl.text = uploaded.downloadUrl;
          _notesCtrl.clear();
          _showManualUrl = false;
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

  Future<void> _confirmDeleteRelease(
    DesktopReleaseZip zip, {
    required bool isActive,
  }) async {
    if (isActive) {
      _snack(
        'Non puoi eliminare la release attiva. Attiva prima un\'altra versione.',
        isError: true,
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Elimina installer'),
        content: Text(
          'Rimuovere ${zip.name} da Firebase Storage?\n'
          'L\'operazione non è reversibile.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _loading = true);
    try {
      await BkCreditCalcDesktopService.deleteReleaseInstaller(
        storagePath: zip.storagePath,
      );
      if (mounted) {
        setState(() => _releasesRefreshKey++);
        _snack('${zip.name} eliminato da Storage.');
      }
    } catch (e) {
      if (mounted) {
        _snack('Eliminazione fallita: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
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
          _cachedActiveVersion = version;
          _cachedActiveUrl = zip.downloadUrl;
          _versionCtrl.text = version;
          _urlCtrl.text = zip.downloadUrl;
          _notesCtrl.clear();
          _showManualUrl = false;
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

  Widget _buildActiveDownloadSection(Map<String, dynamic>? firestoreConfig) {
    final url = _effectiveDownloadUrl(firestoreConfig);
    final version = _effectiveVersion();

    if (url.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Link download',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Compare qui dopo il caricamento del Setup.exe.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
          if (_showManualUrl) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _urlCtrl,
              decoration: const InputDecoration(
                labelText: 'URL download (solo se serve incollarlo)',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ] else
            TextButton.icon(
              onPressed: () => setState(() => _showManualUrl = true),
              icon: const Icon(Icons.link, size: 18),
              label: const Text('Inserisci URL manualmente'),
            ),
        ],
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            version.isNotEmpty ? 'Release attiva · v$version' : 'Release attiva',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.green.shade900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Gli utenti Planet scaricano da questo link:',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
          ),
          const SizedBox(height: 8),
          SelectableText(
            url,
            style: TextStyle(
              fontSize: 11,
              fontFamily: 'Consolas',
              color: Colors.grey.shade900,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: url));
                  _snack('Link copiato.');
                },
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Copia link'),
              ),
              if (!_showManualUrl)
                TextButton(
                  onPressed: () => setState(() => _showManualUrl = true),
                  child: const Text('Modifica URL'),
                ),
            ],
          ),
          if (_showManualUrl) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _urlCtrl,
              decoration: const InputDecoration(
                labelText: 'URL download',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ],
      ),
    );
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
                      const SizedBox(height: 12),
                      Text(
                        '1. Inserisci il numero della nuova versione (es. 1.0.3), non un percorso file.\n'
                        '2. Clicca «Carica Setup.exe» e scegli l installer dalla cartella dist.\n'
                        '3. Il link per Planet viene salvato automaticamente: non serve incollarlo.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.45,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _versionCtrl,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: 'Numero versione',
                          hintText: 'es. 1.0.3',
                          border: const OutlineInputBorder(),
                          helperText:
                              'Deve essere maggiore della versione già installata dagli utenti.',
                        ),
                      ),
                      if (_expectedSetupName() != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'File atteso: ${_expectedSetupName()} · '
                          'Build: ${BkCreditCalcDesktopService.localSetupPathHint(_versionCtrl.text.trim())}',
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
                      _buildActiveDownloadSection(firestoreConfig),
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
                                : () => _saveConfig(
                                      firestoreConfig: firestoreConfig,
                                    ),
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
                          if (_effectiveDownloadUrl(firestoreConfig).isNotEmpty)
                            OutlinedButton.icon(
                              onPressed: () async {
                                final uri = Uri.tryParse(
                                  _effectiveDownloadUrl(firestoreConfig),
                                );
                                if (uri == null) return;
                                await launchUrl(
                                  uri,
                                  mode: LaunchMode.externalApplication,
                                );
                              },
                              icon: const Icon(Icons.open_in_new),
                              label: const Text('Apri link'),
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
                                    IconButton(
                                      tooltip: isActive
                                          ? 'Release attiva: non eliminabile'
                                          : 'Elimina da Storage',
                                      icon: Icon(
                                        Icons.delete_outline,
                                        size: 20,
                                        color: isActive
                                            ? Colors.grey.shade400
                                            : Colors.red.shade700,
                                      ),
                                      onPressed: isActive ||
                                              _loading ||
                                              _uploading
                                          ? null
                                          : () => _confirmDeleteRelease(
                                                zip,
                                                isActive: isActive,
                                              ),
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
