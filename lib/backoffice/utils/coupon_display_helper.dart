import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class CouponEntityDetails {
  final DateTime? appliedAt;
  final DateTime? benefitExpiresAt;
  final bool lifetimeFree;

  const CouponEntityDetails({
    this.appliedAt,
    this.benefitExpiresAt,
    this.lifetimeFree = false,
  });
}

abstract final class CouponDisplayHelper {
  static final _dateFmt = DateFormat('dd/MM/yyyy');

  static String normalizeCode(String raw) =>
      raw.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');

  static String couponBenefitExpiryLabel({
    Timestamp? subscriptionExpiresAt,
    DateTime? couponBenefitExpiresAt,
    bool couponLifetimeFree = false,
  }) {
    if (subscriptionExpiresAt != null) {
      return _dateFmt.format(subscriptionExpiresAt.toDate());
    }
    if (couponBenefitExpiresAt != null) {
      return _dateFmt.format(couponBenefitExpiresAt);
    }
    if (couponLifetimeFree) return 'Non scade';
    return '—';
  }

  static String formatDate(DateTime? value) =>
      value == null ? '—' : _dateFmt.format(value);

  static bool isCouponBenefitExpired({
    Timestamp? subscriptionExpiresAt,
    DateTime? couponBenefitExpiresAt,
    bool couponLifetimeFree = false,
  }) {
    if (couponLifetimeFree &&
        subscriptionExpiresAt == null &&
        couponBenefitExpiresAt == null) {
      return false;
    }

    final now = DateTime.now();
    if (subscriptionExpiresAt != null) {
      return subscriptionExpiresAt.toDate().isBefore(now);
    }
    if (couponBenefitExpiresAt != null) {
      return couponBenefitExpiresAt.isBefore(now);
    }
    return false;
  }

  static Future<CouponEntityDetails> detailsForEntity(
    String couponCode,
    String entityId,
  ) async {
    final code = normalizeCode(couponCode);
    if (code.isEmpty) return const CouponEntityDetails();

    try {
      final snap = await FirebaseFirestore.instance
          .collection('coupons')
          .doc(code)
          .get();
      if (!snap.exists) return const CouponEntityDetails();

      final data = snap.data() ?? {};
      final usedAt = data['lastUsedAt'];
      final benefitExpires = data['benefitExpiresAt'];
      final usedByEntity = data['lastUsedBy']?.toString() == entityId;
      final hasBenefitExpiry = benefitExpires is Timestamp;
      final lifetimeFree = data['lifetimeFree'] as bool? ?? true;

      return CouponEntityDetails(
        appliedAt: usedByEntity && usedAt is Timestamp
            ? usedAt.toDate()
            : null,
        benefitExpiresAt:
            hasBenefitExpiry ? benefitExpires.toDate() : null,
        lifetimeFree: lifetimeFree && !hasBenefitExpiry,
      );
    } catch (_) {
      return const CouponEntityDetails();
    }
  }
}
