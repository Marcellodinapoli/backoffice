import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../utils/bk_storage_upload.dart';

/// Gestione release app Windows CreditCalc su Firestore + Storage.
class BkCreditCalcDesktopService {
  BkCreditCalcDesktopService._();

  static const firestorePath = 'platform_config/credit_calc_desktop';
  static const storageFolder = 'downloads/credit_calc';

  static String msixObjectName(String version) {
    final safeVersion = version.trim().replaceAll(RegExp(r'[^0-9.]'), '');
    if (safeVersion.isEmpty) {
      throw ArgumentError('Versione non valida.');
    }
    return 'CreditCalc-$safeVersion.msix';
  }

  static String setupObjectName(String version) {
    final safeVersion = version.trim().replaceAll(RegExp(r'[^0-9.]'), '');
    if (safeVersion.isEmpty) {
      throw ArgumentError('Versione non valida.');
    }
    return 'CreditCalc-$safeVersion-Setup.exe';
  }

  static String localMsixPathHint(String version) =>
      'creditcalc-tool/dist/${msixObjectName(version)}';

  static String localSetupPathHint(String version) =>
      'creditcalc-tool/dist/${setupObjectName(version)}';

  static String localRecommendedPathHint(String version) =>
      localSetupPathHint(version);

  static DocumentReference<Map<String, dynamic>> get _doc =>
      FirebaseFirestore.instance.doc(firestorePath);

  static Stream<DocumentSnapshot<Map<String, dynamic>>> watchConfig() {
    return _doc.snapshots();
  }

  static Future<Map<String, dynamic>?> loadConfig() async {
    final snap = await _doc.get();
    return snap.data();
  }

  static String setupUrlFromConfig(Map<String, dynamic>? config) {
    if (config == null) return '';
    return (config['windowsInstallerUrl'] ?? '').toString().trim();
  }

  static String msixUrlFromConfig(Map<String, dynamic>? config) {
    if (config == null) return '';
    return (config['windowsMsixUrl'] ?? '').toString().trim();
  }

  /// URL principale per Planet: Setup.exe se presente, altrimenti MSIX.
  static String planetDownloadUrl(Map<String, dynamic> config) {
    final setup = setupUrlFromConfig(config);
    if (setup.isNotEmpty) return setup;

    final msix = msixUrlFromConfig(config);
    if (msix.isNotEmpty) return msix;

    return (config['windowsDownloadUrl'] ?? '').toString().trim();
  }

  static Future<void> saveConfig({
    required bool enabled,
    required String version,
    String? releaseNotes,
    String? windowsInstallerUrl,
    String? windowsMsixUrl,
    bool updateInstaller = false,
    bool updateMsix = false,
  }) async {
    final existing = await loadConfig() ?? {};

    var installer = setupUrlFromConfig(existing);
    var msix = msixUrlFromConfig(existing);

    if (updateInstaller) {
      installer = (windowsInstallerUrl ?? '').trim();
    }
    if (updateMsix) {
      msix = (windowsMsixUrl ?? '').trim();
    }

    final primary = installer.isNotEmpty
        ? installer
        : (msix.isNotEmpty ? msix : planetDownloadUrl(existing));

    final data = <String, dynamic>{
      'enabled': enabled,
      'version': version.trim(),
      'windowsDownloadUrl': primary,
      'releaseNotes': (releaseNotes ?? existing['releaseNotes'] ?? '').toString().trim(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': 'backoffice',
    };

    if (installer.isNotEmpty) {
      data['windowsInstallerUrl'] = installer;
    } else {
      data['windowsInstallerUrl'] = FieldValue.delete();
    }

    if (msix.isNotEmpty) {
      data['windowsMsixUrl'] = msix;
    } else {
      data['windowsMsixUrl'] = FieldValue.delete();
    }

    await _doc.set(data, SetOptions(merge: true));
  }

  static Future<void> setDownloadEnabled(bool enabled) async {
    await _doc.set(
      {
        'enabled': enabled,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': 'backoffice',
      },
      SetOptions(merge: true),
    );
  }

  static String? activeFileNameFromConfig(Map<String, dynamic>? config) {
    if (config == null) return null;
    final url = planetDownloadUrl(config);
    if (url.isEmpty) return null;
    final decoded = Uri.decodeComponent(url);
    final match = RegExp(r'/([^/?]+)(\?|$)').firstMatch(decoded);
    return match?.group(1);
  }

  static int downloadCountFromConfig(Map<String, dynamic>? config) {
    if (config == null) return 0;
    final raw = config['downloadCount'];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }

  static String formatDownloadCount(int count) {
    if (count == 0) return 'Nessun download registrato';
    if (count == 1) return '1 download effettuato';
    return '$count download effettuati';
  }

  static String? versionFromMsixFileName(String fileName) {
    final match = RegExp(
      r'CreditCalc-(\d+\.\d+\.\d+)\.msix',
      caseSensitive: false,
    ).firstMatch(fileName);
    return match?.group(1);
  }

  static String? versionFromSetupFileName(String fileName) {
    final match = RegExp(
      r'CreditCalc-(\d+\.\d+\.\d+)\.?-Setup\.exe',
      caseSensitive: false,
    ).firstMatch(fileName);
    return match?.group(1);
  }

  static Future<DesktopUploadResult> uploadReleaseSetup({
    required String version,
    required void Function(double progress) onProgress,
  }) =>
      _pickAndUpload(
        version: version,
        onProgress: onProgress,
        allowedExtensions: const ['exe'],
        dialogTitle: 'Seleziona CreditCalc-X.Y.Z-Setup.exe',
        kind: _InstallerKind.setup,
      );

  static Future<DesktopUploadResult> uploadReleaseMsix({
    required String version,
    required void Function(double progress) onProgress,
  }) =>
      _pickAndUpload(
        version: version,
        onProgress: onProgress,
        allowedExtensions: const ['msix'],
        dialogTitle: 'Seleziona CreditCalc-X.Y.Z.msix',
        kind: _InstallerKind.msix,
      );

  /// Accetta Setup.exe o MSIX in un unico dialogo.
  static Future<DesktopUploadResult> uploadReleaseInstaller({
    required String version,
    required void Function(double progress) onProgress,
  }) =>
      _pickAndUpload(
        version: version,
        onProgress: onProgress,
        allowedExtensions: const ['exe', 'msix'],
        dialogTitle: 'Seleziona Setup.exe o MSIX',
        kind: _InstallerKind.any,
      );

  static Future<DesktopUploadResult> uploadReleasePackage({
    required String version,
    required void Function(double progress) onProgress,
  }) =>
      uploadReleaseInstaller(version: version, onProgress: onProgress);

  static Future<DesktopUploadResult> _pickAndUpload({
    required String version,
    required void Function(double progress) onProgress,
    required List<String> allowedExtensions,
    required String dialogTitle,
    required _InstallerKind kind,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
      withData: true,
      allowMultiple: false,
      dialogTitle: dialogTitle,
    );
    if (result == null || result.files.isEmpty) {
      throw Exception('Nessun file selezionato.');
    }

    final file = result.files.single;
    final name = file.name.toLowerCase();

    if (kind == _InstallerKind.setup ||
        (kind == _InstallerKind.any && name.endsWith('.exe'))) {
      if (!name.endsWith('.exe')) {
        throw Exception('Seleziona CreditCalc-X.Y.Z-Setup.exe');
      }
      final resolvedVersion =
          versionFromSetupFileName(file.name) ?? version.trim();
      if (resolvedVersion.isEmpty) {
        throw Exception(
          'Inserisci la versione (es. 1.0.5) o usa CreditCalc-1.0.5-Setup.exe.',
        );
      }
      final objectName = setupObjectName(resolvedVersion);
      final url = await _uploadFileToStorage(
        file: file,
        storagePath: '$storageFolder/$objectName',
        contentType: 'application/x-msdownload',
        onProgress: onProgress,
      );
      return DesktopUploadResult(
        downloadUrl: url,
        version: resolvedVersion,
        fileName: objectName,
        kind: DesktopPackageKind.setup,
      );
    }

    if (kind == _InstallerKind.msix ||
        (kind == _InstallerKind.any && name.endsWith('.msix'))) {
      if (!name.endsWith('.msix')) {
        throw Exception('Seleziona CreditCalc-X.Y.Z.msix');
      }
      final resolvedVersion =
          versionFromMsixFileName(file.name) ?? version.trim();
      if (resolvedVersion.isEmpty) {
        throw Exception(
          'Inserisci la versione (es. 1.0.5) o usa CreditCalc-1.0.5.msix.',
        );
      }
      final objectName = msixObjectName(resolvedVersion);
      final url = await _uploadFileToStorage(
        file: file,
        storagePath: '$storageFolder/$objectName',
        contentType: 'application/msix',
        onProgress: onProgress,
      );
      return DesktopUploadResult(
        downloadUrl: url,
        version: resolvedVersion,
        fileName: objectName,
        kind: DesktopPackageKind.msix,
      );
    }

    throw Exception('Formato file non supportato.');
  }

  static Future<String> _uploadFileToStorage({
    required PlatformFile file,
    required String storagePath,
    required String contentType,
    required void Function(double progress) onProgress,
  }) async {
    final ref = FirebaseStorage.instance.ref(storagePath);

    if (kIsWeb && (file.bytes == null || file.bytes!.isEmpty)) {
      throw Exception(
        'Impossibile leggere ${file.name} nel browser. '
        'Prova da Firebase Console → Carica file, oppure esegui il BackOffice su Windows.',
      );
    }
    onProgress(0.01);
    final uploadTask = await startStorageUpload(
      ref: ref,
      file: file,
      metadata: SettableMetadata(
        contentType: contentType,
        customMetadata: {'originalName': file.name},
      ),
    );

    await for (final event in uploadTask.snapshotEvents) {
      final total = event.totalBytes;
      if (total > 0) {
        onProgress(event.bytesTransferred / total);
      }
    }

    final snapshot = await uploadTask;
    if (snapshot.state != TaskState.success) {
      throw Exception('Upload non completato: ${snapshot.state}');
    }
    return snapshot.ref.getDownloadURL();
  }

  static Future<List<DesktopReleaseZip>> listReleaseZips() async {
    final ref = FirebaseStorage.instance.ref(storageFolder);
    final list = await ref.listAll();
    final items = <DesktopReleaseZip>[];

    for (final item in list.items) {
      final lower = item.name.toLowerCase();
      if (!lower.endsWith('.msix') && !lower.endsWith('.exe')) continue;
      final meta = await item.getMetadata();
      items.add(
        DesktopReleaseZip(
          name: item.name,
          storagePath: '$storageFolder/${item.name}',
          downloadUrl: await item.getDownloadURL(),
          sizeBytes: meta.size ?? 0,
          updated: meta.updated,
          kind: isMsixFileName(item.name)
              ? DesktopPackageKind.msix
              : DesktopPackageKind.setup,
        ),
      );
    }

    items.sort(
      (a, b) => (b.updated ?? DateTime.fromMillisecondsSinceEpoch(0))
          .compareTo(a.updated ?? DateTime.fromMillisecondsSinceEpoch(0)),
    );
    return items;
  }

  static Future<void> deleteReleaseInstaller({
    required String storagePath,
  }) async {
    await FirebaseStorage.instance.ref(storagePath).delete();
  }

  static String? versionFromZipName(String fileName) {
    final msix = versionFromMsixFileName(fileName);
    if (msix != null) return msix;

    final setup = versionFromSetupFileName(fileName);
    if (setup != null) return setup;

    if (fileName.toLowerCase().contains('creditcalc')) {
      final loose = RegExp(r'(\d+\.\d+\.\d+)').firstMatch(fileName);
      return loose?.group(1);
    }

    return null;
  }

  static bool isMsixFileName(String fileName) =>
      fileName.toLowerCase().endsWith('.msix');

  static bool isInstallerFileName(String fileName) =>
      fileName.toLowerCase().contains('-setup.exe');

  static bool isReleasePackageFileName(String fileName) {
    final lower = fileName.toLowerCase();
    return lower.endsWith('.msix') || lower.contains('-setup.exe');
  }
}

enum DesktopPackageKind { setup, msix }

enum _InstallerKind { setup, msix, any }

class DesktopUploadResult {
  final String downloadUrl;
  final String version;
  final String fileName;
  final DesktopPackageKind kind;

  const DesktopUploadResult({
    required this.downloadUrl,
    required this.version,
    required this.fileName,
    required this.kind,
  });
}

class DesktopReleaseZip {
  final String name;
  final String storagePath;
  final String downloadUrl;
  final int sizeBytes;
  final DateTime? updated;
  final DesktopPackageKind kind;

  const DesktopReleaseZip({
    required this.name,
    required this.storagePath,
    required this.downloadUrl,
    required this.sizeBytes,
    this.updated,
    required this.kind,
  });
}
