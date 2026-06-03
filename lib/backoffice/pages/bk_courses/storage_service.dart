// lib/backoffice/pages/bk_courses/storage_service.dart

// -----------------------------------------------------------------------------
// IMPORT
// -----------------------------------------------------------------------------
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../utils/bk_storage_upload.dart';

// -----------------------------------------------------------------------------
// STORAGE SERVICE
// -----------------------------------------------------------------------------
class StorageService {
  StorageService._();

  // ---------------------------------------------------------------------------
  // UPLOAD FILE
  // ---------------------------------------------------------------------------
  static Future<String?> uploadCourseAttachment({
    required DocumentReference courseRef,
    required void Function(double progress) onProgress,
  }) async {
    final result =
    await FilePicker.platform.pickFiles(withData: true);

    if (result == null) return null;

    final file = result.files.single;
    final originalName = file.name;

    final safeName =
        '${DateTime.now().millisecondsSinceEpoch}_$originalName';

    final ref = FirebaseStorage.instance
        .ref()
        .child('courses/${courseRef.id}/attachments/$safeName');

    final uploadTask = await startStorageUpload(
      ref: ref,
      file: file,
      metadata: const SettableMetadata(
        contentType: 'application/octet-stream',
      ),
    );

    uploadTask.snapshotEvents.listen((event) {
      if (event.totalBytes > 0) {
        final progress =
            event.bytesTransferred / event.totalBytes;
        onProgress(progress);
      }
    });

    final snapshot = await uploadTask;
    final url = await snapshot.ref.getDownloadURL();

    // aggiorna allegati su Firestore
    final snap = await courseRef.get();
    final data = snap.data() as Map<String, dynamic>?;

    final attachments =
        (data?['attachments'] as List?) ?? [];

    attachments.add(url);

    await courseRef.update({
      'attachments': attachments,
    });

    return originalName;
  }
}
