import 'dart:io' as io show File;

import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';

Future<UploadTask> startStorageUpload({
  required Reference ref,
  required PlatformFile file,
  SettableMetadata? metadata,
}) async {
  final bytes = file.bytes;
  if (bytes != null && bytes.isNotEmpty) {
    return ref.putData(bytes, metadata);
  }
  final path = file.path;
  if (path != null) {
    return ref.putFile(io.File(path), metadata);
  }
  throw Exception('Impossibile leggere il file selezionato.');
}
