import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/cleanup_result.dart';

class DatabaseCleanupService {
  DatabaseCleanupService._();

  static final DatabaseCleanupService instance = DatabaseCleanupService._();

  static const confirmMessage =
      'Verranno eliminati SOLO:\n'
      '• pendingLogins scaduti (oltre 2 minuti)\n'
      '• documenti nelle collezioni test/debug\n\n'
      'Utenti, aziende, corsi e altri dati reali non verranno toccati.';

  static const _obsoleteCollections = [
    'temp',
    'debug',
    'test',
    'old_progress',
    'backup_old',
  ];

  final _db = FirebaseFirestore.instance;

  DateTime? _parseTimestamp(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    return null;
  }

  bool _isExpiredPendingLogin(Map<String, dynamic> data, DateTime limit) {
    final createdAt = _parseTimestamp(data['createdAt']);
    if (createdAt == null) return true;
    return createdAt.isBefore(limit);
  }

  Future<int> _deleteQueryDocs(
    Query<Map<String, dynamic>> query, {
    int pageSize = 500,
  }) async {
    var deleted = 0;

    while (true) {
      final snap = await query.limit(pageSize).get();
      if (snap.docs.isEmpty) break;

      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      deleted += snap.docs.length;

      if (snap.docs.length < pageSize) break;
    }

    return deleted;
  }

  Future<int> _cleanupPendingLogins(DateTime limit, List<String> errors) async {
    var deleted = 0;

    try {
      final snap = await _db.collection('pendingLogins').get();

      for (final doc in snap.docs) {
        if (!_isExpiredPendingLogin(doc.data(), limit)) continue;

        try {
          await doc.reference.delete();
          deleted++;
        } on FirebaseException catch (e) {
          errors.add('pendingLogins/${doc.id}: ${e.code}');
        } catch (e) {
          errors.add('pendingLogins/${doc.id}: $e');
        }
      }
    } on FirebaseException catch (e) {
      errors.add('pendingLogins: ${e.code}');
    } catch (e) {
      errors.add('pendingLogins: $e');
    }

    return deleted;
  }

  Future<int> _cleanupObsoleteCollections(List<String> errors) async {
    var deleted = 0;

    for (final collection in _obsoleteCollections) {
      try {
        deleted += await _deleteQueryDocs(_db.collection(collection));
      } on FirebaseException catch (e) {
        if (e.code != 'permission-denied') {
          errors.add('$collection: ${e.code}');
        }
      } catch (e) {
        errors.add('$collection: $e');
      }
    }

    return deleted;
  }

  Future<CleanupResult> run() async {
    final errors = <String>[];
    final limit = DateTime.now().subtract(const Duration(minutes: 2));

    final pendingLoginsDeleted = await _cleanupPendingLogins(limit, errors);
    final obsoleteDocsDeleted = await _cleanupObsoleteCollections(errors);

    return CleanupResult(
      pendingLoginsDeleted: pendingLoginsDeleted,
      obsoleteDocsDeleted: obsoleteDocsDeleted,
      errors: errors,
    );
  }
}
