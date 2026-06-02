import 'dart:io' as io show File;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Gestione release app Windows CreditCalc su Firestore + Storage.
class BkCreditCalcDesktopService {
  BkCreditCalcDesktopService._();

  static const firestorePath = 'platform_config/credit_calc_desktop';
  static const storageFolder = 'downloads/credit_calc';

  /// Installer consigliato (Inno Setup): `CreditCalc-1.0.1-Setup.exe`.
  static String setupObjectName(String version) {
    final safeVersion = version.trim().replaceAll(RegExp(r'[^0-9.]'), '');
    if (safeVersion.isEmpty) {
      throw ArgumentError('Versione non valida.');
    }
    return 'CreditCalc-$safeVersion-Setup.exe';
  }

  /// ZIP di fallback (estrazione manuale).
  static String zipObjectName(String version) {
    final safeVersion = version.trim().replaceAll(RegExp(r'[^0-9.]'), '');
    if (safeVersion.isEmpty) {
      throw ArgumentError('Versione non valida.');
    }
    return 'CreditCalc-$safeVersion-win64.zip';
  }

  /// Percorso locale dopo build con Inno Setup.
  static String localSetupPathHint(String version) =>
      'creditcalc-tool/dist/${setupObjectName(version)}';

  /// Percorso locale ZIP (solo fallback).
  static String localZipPathHint(String version) =>
      'creditcalc-tool/dist/${zipObjectName(version)}';

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
      // Planet legge prima l installer: allinea anche il campo legacy.
      data['windowsDownloadUrl'] = installer;
    } else if (url.toLowerCase().contains('-setup.exe')) {
      data['windowsInstallerUrl'] = url;
    } else {
      data['windowsInstallerUrl'] = FieldValue.delete();
    }

    await _doc.set(data, SetOptions(merge: true));
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

  /// URL usato da CreditCalc/Planet (installer ha priorità).
  static String planetDownloadUrl(Map<String, dynamic> config) {
    final installer = (config['windowsInstallerUrl'] ?? '').toString().trim();
    if (installer.isNotEmpty) return installer;
    return (config['windowsDownloadUrl'] ?? '').toString().trim();
  }

  /// Carica solo l installer Setup.exe (consigliato per Planet).
  static Future<String> uploadReleaseInstaller({
    required String version,
    required void Function(double progress) onProgress,
  }) =>
      uploadReleasePackage(
        version: version,
        onProgress: onProgress,
        installerOnly: true,
      );

  /// Carica installer `.exe` o ZIP su Storage.
  static Future<String> uploadReleasePackage({
    required String version,
    required void Function(double progress) onProgress,
    bool installerOnly = false,
    bool zipOnly = false,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: installerOnly
          ? ['exe']
          : zipOnly
              ? ['zip']
              : ['exe', 'zip'],
      withData: kIsWeb,
      allowMultiple: false,
      dialogTitle: installerOnly
          ? 'Seleziona CreditCalc-*-Setup.exe'
          : zipOnly
              ? 'Seleziona CreditCalc-*-win64.zip'
              : 'Seleziona Setup.exe o ZIP',
    );
    if (result == null || result.files.isEmpty) {
      throw Exception('Nessun file selezionato.');
    }

    final file = result.files.single;
    final pickedName = file.name.toLowerCase();
    final isExe = pickedName.endsWith('.exe');
    if (installerOnly && !isExe) {
      throw Exception(
        'Devi selezionare CreditCalc-$version-Setup.exe (non lo ZIP).',
      );
    }
    if (zipOnly && !pickedName.endsWith('.zip')) {
      throw Exception('Seleziona un file .zip.');
    }
    if (!isExe && !pickedName.endsWith('.zip')) {
      throw Exception('Seleziona CreditCalc-*-Setup.exe o un file .zip.');
    }

    final objectName = isExe ? setupObjectName(version) : zipObjectName(version);

    return _uploadFileToStorage(
      file: file,
      storagePath: '$storageFolder/$objectName',
      contentType: isExe ? 'application/octet-stream' : 'application/zip',
      onProgress: onProgress,
    );
  }

  static Future<String> _uploadFileToStorage({
    required PlatformFile file,
    required String storagePath,
    required String contentType,
    required void Function(double progress) onProgress,
  }) async {
    final ref = FirebaseStorage.instance.ref(storagePath);

    UploadTask uploadTask;
    if (kIsWeb) {
      if (file.bytes == null || file.bytes!.isEmpty) {
        throw Exception(
          'Impossibile leggere ${file.name} nel browser. '
          'Prova da Firebase Console → Carica file, oppure esegui il BackOffice su Windows.',
        );
      }
      onProgress(0.01);
      uploadTask = ref.putData(
        file.bytes!,
        SettableMetadata(
          contentType: contentType,
          customMetadata: {'originalName': file.name},
        ),
      );
    } else if (file.path != null) {
      uploadTask = ref.putFile(
        io.File(file.path!),
        SettableMetadata(
          contentType: contentType,
          customMetadata: {'originalName': file.name},
        ),
      );
    } else {
      throw Exception('Impossibile leggere il file selezionato.');
    }

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

  /// Carica lo ZIP su Storage (legacy).
  static Future<String> uploadReleaseZip({
    required String version,
    required void Function(double progress) onProgress,
  }) =>
      uploadReleasePackage(version: version, onProgress: onProgress);

  /// Elenco installer e ZIP su Storage (`downloads/credit_calc/`).
  static Future<List<DesktopReleaseZip>> listReleaseZips() async {
    final ref = FirebaseStorage.instance.ref(storageFolder);
    final list = await ref.listAll();
    final items = <DesktopReleaseZip>[];

    for (final item in list.items) {
      final lower = item.name.toLowerCase();
      if (!lower.endsWith('.zip') && !lower.endsWith('.exe')) continue;
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

  /// Estrae `1.0.1` da `CreditCalc-1.0.1-Setup.exe` o `CreditCalc-1.0.1-win64.zip`.
  static String? versionFromZipName(String fileName) {
    final setup = RegExp(r'CreditCalc-(\d+\.\d+\.\d+)-Setup\.exe',
            caseSensitive: false)
        .firstMatch(fileName);
    if (setup != null) return setup.group(1);

    final zip = RegExp(r'CreditCalc-(\d+\.\d+\.\d+)-win64\.zip',
            caseSensitive: false)
        .firstMatch(fileName);
    return zip?.group(1);
  }

  static bool isInstallerFileName(String fileName) =>
      fileName.toLowerCase().endsWith('.exe');
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
