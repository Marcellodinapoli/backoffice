import 'dart:async';

import 'package:credit_calc_core/credit_calc_core.dart';
import 'package:flutter/foundation.dart';

/// Segnale locale dopo modifica piani (`settings/plan_limits`).
abstract final class PlanLimitsRefresh {
  static final ValueNotifier<int> revision = ValueNotifier(0);

  static StreamSubscription<void>? _configSub;

  static void start() {
    _configSub?.cancel();
    _configSub = PublicPlanLimitsConfigService.onConfigChanged.listen((_) {
      bump();
    });
  }

  static void stop() {
    _configSub?.cancel();
    _configSub = null;
  }

  static void bump() {
    revision.value++;
  }
}
