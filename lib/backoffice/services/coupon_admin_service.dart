import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CouponRecord {
  final String code;
  final bool enabled;
  final bool lifetimeFree;
  final int usedCount;
  final int? maxUses;
  final DateTime? expiresAt;
  final DateTime? benefitExpiresAt;
  final String? plan;
  final String? label;
  final DateTime? createdAt;

  const CouponRecord({
    required this.code,
    required this.enabled,
    required this.lifetimeFree,
    required this.usedCount,
    this.maxUses,
    this.expiresAt,
    this.benefitExpiresAt,
    this.plan,
    this.label,
    this.createdAt,
  });

  factory CouponRecord.fromDoc(String id, Map<String, dynamic> data) {
    final expires = data['expiresAt'];
    final benefitExpires = data['benefitExpiresAt'];
    final created = data['createdAt'];
    final maxUsesRaw = data['maxUses'];
    final usedRaw = data['usedCount'];

    return CouponRecord(
      code: id,
      enabled: data['enabled'] == true,
      lifetimeFree: data['lifetimeFree'] as bool? ?? true,
      usedCount: usedRaw is int
          ? usedRaw
          : usedRaw is num
              ? usedRaw.toInt()
              : 0,
      maxUses: maxUsesRaw is int
          ? maxUsesRaw
          : maxUsesRaw is num
              ? maxUsesRaw.toInt()
              : null,
      expiresAt: expires is Timestamp ? expires.toDate() : null,
      benefitExpiresAt:
          benefitExpires is Timestamp ? benefitExpires.toDate() : null,
      plan: (data['plan'] ?? '').toString().trim().isEmpty
          ? null
          : (data['plan'] ?? '').toString(),
      label: (data['label'] ?? '').toString().trim().isEmpty
          ? null
          : (data['label'] ?? '').toString(),
      createdAt: created is Timestamp ? created.toDate() : null,
    );
  }

  bool get exhausted =>
      maxUses != null && maxUses! > 0 && usedCount >= maxUses!;

  bool get expired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now());
}

abstract final class CouponAdminService {
  static final _col = FirebaseFirestore.instance.collection('coupons');

  static String normalizeCode(String raw) =>
      raw.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');

  static DateTime endOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

  static Stream<List<CouponRecord>> watchCoupons() {
    return _col.snapshots().map((snap) {
      final list = snap.docs
          .map((d) => CouponRecord.fromDoc(d.id, d.data()))
          .toList();
      list.sort((a, b) {
        final ac = a.createdAt?.millisecondsSinceEpoch ?? 0;
        final bc = b.createdAt?.millisecondsSinceEpoch ?? 0;
        return bc.compareTo(ac);
      });
      return list;
    });
  }

  static Future<void> createCoupon({
    required String code,
    String? label,
    int? maxUses,
    DateTime? expiresAt,
    required DateTime benefitExpiresAt,
    String? restrictedPlan,
  }) async {
    final normalized = normalizeCode(code);
    if (normalized.isEmpty) {
      throw ArgumentError('Codice coupon obbligatorio');
    }

    final existing = await _col.doc(normalized).get();
    if (existing.exists) {
      throw StateError('Esiste già un coupon con questo codice.');
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    final benefitEnd = endOfDay(benefitExpiresAt);
    await _col.doc(normalized).set({
      'enabled': true,
      'type': 'reset_limits',
      'lifetimeFree': false,
      'usedCount': 0,
      'benefitExpiresAt': Timestamp.fromDate(benefitEnd),
      if (label != null && label.trim().isNotEmpty) 'label': label.trim(),
      if (maxUses != null && maxUses > 0) 'maxUses': maxUses,
      if (expiresAt != null)
        'expiresAt': Timestamp.fromDate(endOfDay(expiresAt)),
      if (restrictedPlan != null && restrictedPlan.trim().isNotEmpty)
        'plan': restrictedPlan.trim().toLowerCase(),
      'createdAt': FieldValue.serverTimestamp(),
      if (uid != null) 'createdBy': uid,
    });
  }

  static Future<void> setEnabled({
    required String code,
    required bool enabled,
  }) async {
    final normalized = normalizeCode(code);
    await _col.doc(normalized).set(
      {'enabled': enabled},
      SetOptions(merge: true),
    );
  }

  static Future<void> updateCoupon({
    required String code,
    String? label,
    int? maxUses,
    bool clearMaxUses = false,
    DateTime? expiresAt,
    bool clearExpiresAt = false,
    required DateTime benefitExpiresAt,
    String? restrictedPlan,
    bool clearPlan = false,
  }) async {
    final normalized = normalizeCode(code);
    final snap = await _col.doc(normalized).get();
    if (!snap.exists) {
      throw StateError('Coupon non trovato.');
    }

    final updates = <String, dynamic>{
      'benefitExpiresAt': Timestamp.fromDate(endOfDay(benefitExpiresAt)),
      'lifetimeFree': false,
    };

    final trimmedLabel = label?.trim() ?? '';
    if (trimmedLabel.isNotEmpty) {
      updates['label'] = trimmedLabel;
    } else {
      updates['label'] = FieldValue.delete();
    }

    if (maxUses != null && maxUses > 0) {
      updates['maxUses'] = maxUses;
    } else if (clearMaxUses) {
      updates['maxUses'] = FieldValue.delete();
    }

    if (expiresAt != null) {
      updates['expiresAt'] = Timestamp.fromDate(endOfDay(expiresAt));
    } else if (clearExpiresAt) {
      updates['expiresAt'] = FieldValue.delete();
    }

    if (restrictedPlan != null && restrictedPlan.trim().isNotEmpty) {
      updates['plan'] = restrictedPlan.trim().toLowerCase();
    } else if (clearPlan) {
      updates['plan'] = FieldValue.delete();
    }

    await _col.doc(normalized).set(updates, SetOptions(merge: true));
  }

  static Future<void> deleteCoupon(String code) async {
    final normalized = normalizeCode(code);
    if (normalized.isEmpty) {
      throw ArgumentError('Codice coupon non valido.');
    }
    await _col.doc(normalized).delete();
  }
}

String couponPlanLabel(String? planId) {
  switch (planId?.toLowerCase()) {
    case 'free':
      return 'Gratis';
    case 'plus':
      return 'Plus';
    case 'enterprise':
      return 'Enterprise';
    default:
      return planId ?? '';
  }
}
