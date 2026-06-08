import 'package:cloud_firestore/cloud_firestore.dart';

/// Stati account allineati a CreditPlanet (`user_account_status.dart`).
abstract final class UserAccountStatus {
  /// Stati Firestore considerati bloccati (dashboard KPI).
  static const blockedStatusValues = ['blocked', 'standby', 'disabled'];

  static bool isBlocked(String? status) {
    return blockedStatusValues.contains(status);
  }

  /// Work: `pending` legacy → `active` (registrazione già approvata lato app).
  static String workCollaboratorStatus(String? status) {
    final value = (status ?? 'active').toString().trim();
    if (value == 'pending') return 'active';
    return value;
  }

  static String displayStatus(String? status, {required String type}) {
    if (type == 'work') {
      return workCollaboratorStatus(status);
    }
    return (status ?? 'pending').toString();
  }

  static String defaultRawStatus(String type) {
    return type == 'work' ? 'active' : 'pending';
  }

  static bool needsAdminActivation(String? status, {required String type}) {
    return displayStatus(status, type: type) != 'active';
  }

  /// Formato `dd/MM/yyyy HH:mm` (allineato a CreditPlanet).
  static String formatDateTime(dynamic ts) {
    if (ts == null) return 'N/D';
    try {
      final DateTime d;
      if (ts is Timestamp) {
        d = ts.toDate().toLocal();
      } else if (ts is DateTime) {
        d = ts.toLocal();
      } else {
        return 'N/D';
      }
      return '${d.day.toString().padLeft(2, '0')}/'
          '${d.month.toString().padLeft(2, '0')}/'
          '${d.year} '
          '${d.hour.toString().padLeft(2, '0')}:'
          '${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return 'N/D';
    }
  }

  static Map<String, dynamic> activationUpdate() {
    return {
      'status': 'active',
      'motivazione': FieldValue.delete(),
      'blockReason': FieldValue.delete(),
      'block_reason': FieldValue.delete(),
      'blockedReason': FieldValue.delete(),
      'standbyReason': FieldValue.delete(),
      'blockedAt': FieldValue.delete(),
      'blocked_at': FieldValue.delete(),
      'blockDate': FieldValue.delete(),
      'standbyAt': FieldValue.delete(),
      'blockedBy': FieldValue.delete(),
    };
  }
}
