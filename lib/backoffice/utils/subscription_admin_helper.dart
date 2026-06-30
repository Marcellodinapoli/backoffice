import 'package:credit_calc_core/credit_calc_core.dart';

abstract final class SubscriptionAdminHelper {
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

  static String _normalizePublicPlanId(String planId) =>
      switch (planId.toLowerCase()) {
        'plus' => 'plus',
        'enterprise' => 'enterprise',
        _ => 'free',
      };

  static bool isUnlimitedPublicPlan(String planId) {
    final limits = publicPlanLimitsForPlan(_normalizePublicPlanId(planId));
    return limits.enforcement == PublicPlanEnforcement.fairUse;
  }

  /// Riga piano in lista utenti: null se FREE con limiti hard; "Senza limiti" se fair use.
  static String? publicUserListPlanLineFromData(
    Map<String, dynamic> data, {
    required String type,
  }) {
    if (type != 'public') return null;
    final planId = data['subscriptionPlan']?.toString() ?? 'free';
    if (data['lifetimeAccess'] == true || isUnlimitedPublicPlan(planId)) {
      return 'Senza limiti';
    }
    if (_normalizePublicPlanId(planId) != 'free') {
      return 'Piano: ${planLabel(planId)}';
    }
    return null;
  }
}
