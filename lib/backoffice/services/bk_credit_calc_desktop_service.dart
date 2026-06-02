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
  }) async {
    await _doc.set({
      'enabled': enabled,
      'version': version.trim(),
      'windowsDownloadUrl': windowsDownloadUrl.trim(),
      'releaseNotes': (releaseNotes ?? '').trim(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': 'backoffice',
    }, SetOptions(merge: true));
  }

  /// Carica installer `.exe` (consigliato) o ZIP su Storage.
  static Future<String> uploadReleasePackage({
    required String version,
    required void Function(double progress) onProgress,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['exe', 'zip'],
      withData: kIsWeb,
    );
    if (result == null || result.files.isEmpty) {
      throw Exception('Nessun file selezionato.');
    }

    final file = result.files.single;
    final pickedName = (file.name).toLowerCase();
    final isExe = pickedName.endsWith('.exe');
    if (!isExe && !pickedName.endsWith('.zip')) {
      throw Exception('Seleziona CreditCalc-*-Setup.exe o un file .zip.');
    }

    final objectName = isExe ? setupObjectName(version) : zipObjectName(version);

    final ref = FirebaseStorage.instance.ref('$storageFolder/$objectName');
    final contentType = isExe
        ? 'application/vnd.microsoft.portable-executable'
        : 'application/zip';

    UploadTask uploadTask;
    if (kIsWeb) {
      if (file.bytes == null) {
        throw Exception('Impossibile leggere il file.');
      }
      uploadTask = ref.putData(
        file.bytes!,
        SettableMetadata(contentType: contentType),
      );
    } else if (file.path != null) {
      uploadTask = ref.putFile(
        io.File(file.path!),
        SettableMetadata(contentType: contentType),
      );
    } else {
      throw Exception('Impossibile leggere il file.');
    }

    uploadTask.snapshotEvents.listen((event) {
      if (event.totalBytes > 0) {
        onProgress(event.bytesTransferred / event.totalBytes);
      }
    });

    final snapshot = await uploadTask;
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
