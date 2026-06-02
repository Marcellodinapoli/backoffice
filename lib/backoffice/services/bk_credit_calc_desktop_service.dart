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

  /// Carica lo ZIP su Storage e aggiorna [windowsDownloadUrl] su Firestore.
  static Future<String> uploadReleaseZip({
    required String version,
    required void Function(double progress) onProgress,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
      withData: kIsWeb,
    );
    if (result == null || result.files.isEmpty) {
      throw Exception('Nessun file selezionato.');
    }

    final file = result.files.single;
    final safeVersion = version.trim().replaceAll(RegExp(r'[^\d.]'), '');
    if (safeVersion.isEmpty) {
      throw Exception('Versione non valida.');
    }

    final objectName = 'CreditCalc-$safeVersion-win64.zip';
    final ref = FirebaseStorage.instance.ref('$storageFolder/$objectName');

    UploadTask uploadTask;
    if (kIsWeb) {
      if (file.bytes == null) {
        throw Exception('Impossibile leggere il file ZIP.');
      }
      uploadTask = ref.putData(
        file.bytes!,
        SettableMetadata(contentType: 'application/zip'),
      );
    } else if (file.path != null) {
      uploadTask = ref.putFile(
        io.File(file.path!),
        SettableMetadata(contentType: 'application/zip'),
      );
    } else {
      throw Exception('Impossibile leggere il file ZIP.');
    }

    uploadTask.snapshotEvents.listen((event) {
      if (event.totalBytes > 0) {
        onProgress(event.bytesTransferred / event.totalBytes);
      }
    });

    final snapshot = await uploadTask;
    return snapshot.ref.getDownloadURL();
  }
}
