import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';

import 'bk_storage_upload_stub.dart'
    if (dart.library.io) 'bk_storage_upload_io.dart' as impl;

Future<UploadTask> startStorageUpload({
  required Reference ref,
  required PlatformFile file,
  SettableMetadata? metadata,
}) =>
    impl.startStorageUpload(ref: ref, file: file, metadata: metadata);
