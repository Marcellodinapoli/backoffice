import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const double subscriptionLimitWarningRatio = 0.8;

class SubscriptionCardInfo {
  final String planLabel;
  final String expiryLabel;
  final int? used;
  final int? limit;
  final bool unlimited;
  final String limitLabel;

  const SubscriptionCardInfo({
    required this.planLabel,
    required this.expiryLabel,
    this.used,
    this.limit,
    this.unlimited = false,
    this.limitLabel = 'Utilizzo limite',
  });

  double? get ratio {
    if (unlimited || limit == null || limit! <= 0) return null;
    return ((used ?? 0) / limit!).clamp(0.0, 1.0);
  }
}

abstract final class SubscriptionAdminHelper {
  static final _dateFmt = DateFormat('dd/MM/yyyy');

  static String planLabel(String? planId) {
    return switch ((planId ?? 'free').toLowerCase()) {
      'plus' => 'Plus',
      'enterprise' || 'azienda' => 'Enterprise',
      'starter' => 'Starter',
      'business' => 'Business',
      'professional' => 'Professional',
      'free' => 'Gratis',
      _ => planId ?? 'Gratis',
    };
  }

  static int companyCollaboratorLimit(String planId, [int? stored]) {
    if (stored != null && stored > 0) return stored;
    return switch (planId.toLowerCase()) {
      'starter' || 'plus' => 10,
      'business' => 25,
      'professional' => 50,
      'enterprise' || 'azienda' => 100,
      _ => 2,
    };
  }

  static SubscriptionCardInfo fromCompanyMap(Map<String, dynamic> data) {
    final planId = (data['subscriptionPlan'] ?? 'free').toString();
    return SubscriptionCardInfo(
      planLabel: planLabel(planId),
      expiryLabel: _expiryLabel(data),
      used: _readInt(data['activeWorkUsers']),
      limit: companyCollaboratorLimit(
        planId,
        _readIntOrNull(data['collaboratorLimit']),
      ),
      limitLabel: 'Collaboratori attivi',
    );
  }

  static SubscriptionCardInfo fromPublicUserMap(Map<String, dynamic> data) {
    final planId = (data['subscriptionPlan'] ?? 'free').toString();
    if (planId == 'enterprise' || data['lifetimeAccess'] == true) {
      return SubscriptionCardInfo(
        planLabel: planLabel(planId),
        expiryLabel: _expiryLabel(data),
        unlimited: true,
        limitLabel: 'Utilizzo piano',
      );
    }

    return SubscriptionCardInfo(
      planLabel: planLabel(planId),
      expiryLabel: _expiryLabel(data),
      limitLabel: 'Utilizzo piano',
    );
  }

  static Future<SubscriptionCardInfo> loadPublicUsage(String userId) async {
    final userSnap =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();
    final data = userSnap.data() ?? {};
    final planId = (data['subscriptionPlan'] ?? 'free').toString();

    if (planId == 'enterprise' || data['lifetimeAccess'] == true) {
      return SubscriptionCardInfo(
        planLabel: planLabel(planId),
        expiryLabel: _expiryLabel(data),
        unlimited: true,
        limitLabel: 'Utilizzo piano',
      );
    }

    final limits = _publicLimits(planId);
    final monthlySnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('public_usage')
        .doc('monthly')
        .get();
    final monthly = monthlySnap.data() ?? {};
    final monthKey = _monthKey();
    final counts = monthly['monthKey'] == monthKey
        ? Map<String, dynamic>.from(
            (monthly['counts'] as Map?)?.cast<String, dynamic>() ?? {},
          )
        : <String, dynamic>{};

    var maxUsed = 0;
    var maxLimit = 1;
    for (final entry in limits.entries) {
      int used;
      if (entry.key == 'activeCourses') {
        try {
          used = await _countActiveCourses(userId);
        } catch (_) {
          used = _readInt(counts[entry.key]);
        }
      } else {
        used = _readInt(counts[entry.key]);
      }
      if (entry.value <= 0) continue;
      if (used / entry.value > maxUsed / maxLimit) {
        maxUsed = used;
        maxLimit = entry.value;
      }
    }

    return SubscriptionCardInfo(
      planLabel: planLabel(planId),
      expiryLabel: _expiryLabel(data),
      used: maxUsed,
      limit: maxLimit,
      limitLabel: 'Utilizzo piano',
    );
  }

  static String _expiryLabel(Map<String, dynamic> data) {
    if (data['lifetimeAccess'] == true) return 'Non scade';
    final expires = data['subscriptionExpiresAt'];
    if (expires is Timestamp) {
      return 'Scade il ${_dateFmt.format(expires.toDate())}';
    }
    final status = (data['subscriptionStatus'] ?? 'active').toString();
    if (status == 'cancelled') {
      final cancelled = data['subscriptionCancelledAt'];
      if (cancelled is Timestamp) {
        return 'Annullato il ${_dateFmt.format(cancelled.toDate())}';
      }
      return 'Annullato';
    }
    if (status == 'pending') return 'In attivazione';
    final plan = (data['subscriptionPlan'] ?? 'free').toString();
    if (plan == 'free') return 'Senza scadenza';
    return '—';
  }

  static Map<String, int> _publicLimits(String planId) {
    if (planId == 'plus') {
      return const {
        'activeCourses': 50,
        'quiz': 200,
        'warmup': 100,
        'roleplay': 80,
        'contestation': 50,
        'repaymentPlan': 20,
        'balanceWriteOff': 15,
        'itinerary': 20,
        'jobApplication': 50,
      };
    }
    return const {
      'activeCourses': 3,
      'quiz': 10,
      'warmup': 5,
      'roleplay': 2,
      'contestation': 3,
      'repaymentPlan': 1,
      'balanceWriteOff': 1,
      'itinerary': 2,
      'jobApplication': 3,
    };
  }

  static Future<int> _countActiveCourses(String userId) async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('course_progress')
        .where('status', isEqualTo: 'active')
        .get();
    return snap.size;
  }

  static String _monthKey([DateTime? dt]) {
    final d = dt ?? DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}';
  }

  static int _readInt(dynamic raw, [int fallback = 0]) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return fallback;
  }

  static int? _readIntOrNull(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return null;
  }
}

class SubscriptionCardSummary extends StatelessWidget {
  final SubscriptionCardInfo info;

  const SubscriptionCardSummary({super.key, required this.info});

  Color _barColor(double ratio) {
    if (ratio >= 1.0) return const Color(0xFFD32F2F);
    if (ratio >= subscriptionLimitWarningRatio) return const Color(0xFFE65100);
    return const Color(0xFF2E7D32);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _row('Piano', info.planLabel, bold: true),
        const SizedBox(height: 4),
        _row('Scadenza', info.expiryLabel),
        const SizedBox(height: 8),
        if (info.unlimited)
          Text(
            '${info.limitLabel}: illimitato',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          )
        else if (info.limit != null) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  info.limitLabel,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
              ),
              Text(
                '${info.used ?? 0}/${info.limit}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _barColor(info.ratio ?? 0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: info.ratio,
              minHeight: 8,
              backgroundColor: Colors.grey.shade300,
              color: _barColor(info.ratio ?? 0),
            ),
          ),
          if ((info.ratio ?? 0) >= subscriptionLimitWarningRatio &&
              (info.ratio ?? 0) < 1.0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Soglia ${(subscriptionLimitWarningRatio * 100).round()}% raggiunta',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFFE65100),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade800,
              fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }
}
