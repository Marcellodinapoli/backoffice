import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';

Future<UploadTask> startStorageUpload({
  required Reference ref,
  required PlatformFile file,
  SettableMetadata? metadata,
}) async {
  final bytes = file.bytes;
  if (bytes == null || bytes.isEmpty) {
    throw Exception('Impossibile leggere il file selezionato.');
  }
  return ref.putData(bytes, metadata);
}
