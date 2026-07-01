import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../utils/coupon_display_helper.dart';

class CouponCardSummary extends StatelessWidget {
  final String entityId;
  final String? couponCode;
  final Timestamp? subscriptionExpiresAt;

  const CouponCardSummary({
    super.key,
    required this.entityId,
    this.couponCode,
    this.subscriptionExpiresAt,
  });

  @override
  Widget build(BuildContext context) {
    final code = couponCode?.trim();
    if (code == null || code.isEmpty) return const SizedBox.shrink();

    return FutureBuilder<CouponEntityDetails>(
      future: CouponDisplayHelper.detailsForEntity(code, entityId),
      builder: (context, snap) {
        final details = snap.data ?? const CouponEntityDetails();
        final benefitExpiry = CouponDisplayHelper.couponBenefitExpiryLabel(
          subscriptionExpiresAt: subscriptionExpiresAt,
          couponBenefitExpiresAt: details.benefitExpiresAt,
          couponLifetimeFree: details.lifetimeFree,
        );
        final expired = CouponDisplayHelper.isCouponBenefitExpired(
          subscriptionExpiresAt: subscriptionExpiresAt,
          couponBenefitExpiresAt: details.benefitExpiresAt,
          couponLifetimeFree: details.lifetimeFree,
        );

        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Coupon: $code',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Inserito: ${CouponDisplayHelper.formatDate(details.appliedAt)}',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
              Text(
                'Effetto limiti fino al: $benefitExpiry',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
              if (expired)
                const Text(
                  'Scaduto',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.red,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
