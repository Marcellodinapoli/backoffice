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

  /// Pacchetto MSIX (formato consigliato): `CreditCalc-1.0.2.msix`.
  static String msixObjectName(String version) {
    final safeVersion = version.trim().replaceAll(RegExp(r'[^0-9.]'), '');
    if (safeVersion.isEmpty) {
      throw ArgumentError('Versione non valida.');
    }
    return 'CreditCalc-$safeVersion.msix';
  }

  /// Legacy Inno Setup (solo elenco Storage).
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

  static DocumentReference<Map<String, dynamic>> get _doc =>
      FirebaseFirestore.instance.doc(firestorePath);

  static Stream<DocumentSnapshot<Map<String, dynamic>>> watchConfig() {
    return _doc.snapshots();
  }

  static Future<Map<String, dynamic>?> loadConfig() async {
    final snap = await _doc.get();
    return snap.data();
  }

  static Future<void> saveConfig({
    required bool enabled,
    required String version,
    required String windowsDownloadUrl,
    String? releaseNotes,
    String? windowsInstallerUrl,
  }) async {
    final url = windowsDownloadUrl.trim();
    final data = <String, dynamic>{
      'enabled': enabled,
      'version': version.trim(),
      'windowsDownloadUrl': url,
      'releaseNotes': (releaseNotes ?? '').trim(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': 'backoffice',
    };

    final installer = windowsInstallerUrl?.trim() ?? '';
    if (installer.isNotEmpty) {
      data['windowsInstallerUrl'] = installer;
      data['windowsDownloadUrl'] = installer;
    } else if (_isReleasePackageUrl(url)) {
      data['windowsInstallerUrl'] = url;
    } else {
      data['windowsInstallerUrl'] = FieldValue.delete();
    }

    await _doc.set(data, SetOptions(merge: true));
  }

  /// Aggiorna solo il flag visibile su Planet (merge, senza richiedere URL/versione).
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

  static bool _isReleasePackageUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('.msix') || lower.contains('-setup.exe');
  }

  /// Nome file attivo per Planet (da config Firestore).
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

  /// URL usato da CreditCalc/Planet (installer ha priorità).
  static String planetDownloadUrl(Map<String, dynamic> config) {
    final installer = (config['windowsInstallerUrl'] ?? '').toString().trim();
    if (installer.isNotEmpty) return installer;
    return (config['windowsDownloadUrl'] ?? '').toString().trim();
  }

  static String? versionFromMsixFileName(String fileName) {
    final match = RegExp(
      r'CreditCalc-(\d+\.\d+\.\d+)\.msix',
      caseSensitive: false,
    ).firstMatch(fileName);
    return match?.group(1);
  }

  /// Estrae `1.0.2` da `CreditCalc-1.0.2-Setup.exe` (tollera anche `1.0.2.-Setup`).
  static String? versionFromSetupFileName(String fileName) {
    final match = RegExp(
      r'CreditCalc-(\d+\.\d+\.\d+)\.?-Setup\.exe',
      caseSensitive: false,
    ).firstMatch(fileName);
    return match?.group(1);
  }

  /// Carica CreditCalc-X.Y.Z.msix su Storage e attiva su Firestore.
  static Future<DesktopUploadResult> uploadReleaseMsix({
    required String version,
    required void Function(double progress) onProgress,
  }) =>
      _pickAndUploadMsix(version: version, onProgress: onProgress);

  static Future<DesktopUploadResult> uploadReleaseInstaller({
    required String version,
    required void Function(double progress) onProgress,
  }) =>
      uploadReleaseMsix(version: version, onProgress: onProgress);

  static Future<DesktopUploadResult> uploadReleasePackage({
    required String version,
    required void Function(double progress) onProgress,
  }) =>
      uploadReleaseMsix(version: version, onProgress: onProgress);

  static Future<DesktopUploadResult> _pickAndUploadMsix({
    required String version,
    required void Function(double progress) onProgress,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['msix'],
      withData: true,
      allowMultiple: false,
      dialogTitle: 'Seleziona CreditCalc-X.Y.Z.msix',
    );
    if (result == null || result.files.isEmpty) {
      throw Exception('Nessun file selezionato.');
    }

    final file = result.files.single;
    final name = file.name.toLowerCase();
    if (name.endsWith('.zip')) {
      throw Exception(
        'Hai selezionato uno ZIP. Scegli il file MSIX '
        '(es. CreditCalc-1.0.2.msix).',
      );
    }
    if (!name.endsWith('.msix')) {
      throw Exception(
        'Seleziona CreditCalc-X.Y.Z.msix dalla cartella creditcalc-tool/dist.',
      );
    }

    final fromFile = versionFromMsixFileName(file.name);
    final resolvedVersion = fromFile ?? version.trim();
    if (resolvedVersion.isEmpty) {
      throw Exception(
        'Inserisci la versione (es. 1.0.2) o usa CreditCalc-1.0.2.msix.',
      );
    }

    final url = await _uploadFileToStorage(
      file: file,
      storagePath: '$storageFolder/${msixObjectName(resolvedVersion)}',
      contentType: 'application/msix',
      onProgress: onProgress,
    );
    return DesktopUploadResult(
      downloadUrl: url,
      version: resolvedVersion,
      fileName: msixObjectName(resolvedVersion),
    );
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

  static Future<DesktopUploadResult> uploadReleaseZip({
    required String version,
    required void Function(double progress) onProgress,
  }) =>
      uploadReleaseMsix(version: version, onProgress: onProgress);

  /// MSIX e Setup.exe legacy su Storage.
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

    final zip = RegExp(
      r'CreditCalc-(\d+\.\d+\.\d+)-win64\.zip',
      caseSensitive: false,
    ).firstMatch(fileName);
    if (zip != null) return zip.group(1);

    if (fileName.toLowerCase().contains('creditcalc')) {
      final loose = RegExp(r'(\d+\.\d+\.\d+)').firstMatch(fileName);
      return loose?.group(1);
    }

    return null;
  }

  static bool isMsixFileName(String fileName) =>
      fileName.toLowerCase().endsWith('.msix');

  static bool isInstallerFileName(String fileName) =>
      fileName.toLowerCase().endsWith('.exe');

  static bool isReleasePackageFileName(String fileName) {
    final lower = fileName.toLowerCase();
    return lower.endsWith('.msix') || lower.contains('-setup.exe');
  }
}

class DesktopUploadResult {
  final String downloadUrl;
  final String version;
  final String fileName;

  const DesktopUploadResult({
    required this.downloadUrl,
    required this.version,
    required this.fileName,
  });
}

class DesktopReleaseZip {
  final String name;
  final String storagePath;
  final String downloadUrl;
  final int sizeBytes;
  final DateTime? updated;

  const DesktopReleaseZip({
    required this.name,
    required this.storagePath,
    required this.downloadUrl,
    required this.sizeBytes,
    this.updated,
  });
}
