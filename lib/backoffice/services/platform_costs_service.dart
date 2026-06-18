import 'package:cloud_firestore/cloud_firestore.dart';

/// Metriche mensili per piattaforma (documento `settings/platform_costs/months/{yyyy-MM}`).
class PlatformMonthCosts {
  const PlatformMonthCosts({
    this.bunnyStorageGb = 0,
    this.bunnyTrafficGb = 0,
    this.hetznerMonthlyEur = 17,
    this.openAiAmountEur = 0,
    this.firebaseReads = 0,
    this.firebaseWrites = 0,
    this.firebaseStorageMb = 0,
  });

  final double bunnyStorageGb;
  final double bunnyTrafficGb;
  final double hetznerMonthlyEur;
  final double openAiAmountEur;
  final int firebaseReads;
  final int firebaseWrites;
  final int firebaseStorageMb;

  factory PlatformMonthCosts.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const PlatformMonthCosts();

    final bunny = data['bunny'] as Map<String, dynamic>? ?? {};
    final hetzner = data['hetzner'] as Map<String, dynamic>? ?? {};
    final openai = data['openai'] as Map<String, dynamic>? ?? {};
    final firebase = data['firebase'] as Map<String, dynamic>? ?? {};

    return PlatformMonthCosts(
      bunnyStorageGb: _asDouble(bunny['storageGb']),
      bunnyTrafficGb: _asDouble(bunny['trafficGb']),
      hetznerMonthlyEur: _asDouble(hetzner['monthlyFlat'], fallback: 17),
      openAiAmountEur: _asDouble(openai['amountEur']),
      firebaseReads: _asInt(firebase['reads']),
      firebaseWrites: _asInt(firebase['writes']),
      firebaseStorageMb: _asInt(firebase['storageMb']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'bunny': {
        'storageGb': bunnyStorageGb,
        'trafficGb': bunnyTrafficGb,
      },
      'hetzner': {
        'monthlyFlat': hetznerMonthlyEur,
      },
      'openai': {
        'amountEur': openAiAmountEur,
      },
      'firebase': {
        'reads': firebaseReads,
        'writes': firebaseWrites,
        'storageMb': firebaseStorageMb,
      },
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  double costBunny() =>
      bunnyStorageGb * 0.01 + bunnyTrafficGb * 0.02;

  double costHetzner() => hetznerMonthlyEur;

  double costOpenAi() => openAiAmountEur;

  double costFirebase() =>
      firebaseReads * 0.000001 +
      firebaseWrites * 0.000005 +
      (firebaseStorageMb / 1024) * 0.18;

  double total() =>
      costBunny() + costHetzner() + costOpenAi() + costFirebase();

  static double _asDouble(dynamic value, {double fallback = 0}) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? fallback;
  }

  static int _asInt(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }
}

class PlatformCostsService {
  PlatformCostsService._();

  static const _settingsDoc = 'platform_costs';

  static DocumentReference<Map<String, dynamic>> _monthRef(String monthKey) {
    return FirebaseFirestore.instance
        .collection('settings')
        .doc(_settingsDoc)
        .collection('months')
        .doc(monthKey);
  }

  static Stream<PlatformMonthCosts> watchMonth(String monthKey) {
    return _monthRef(monthKey).snapshots().map(
          (snap) => PlatformMonthCosts.fromMap(snap.data()),
        );
  }

  static Future<void> saveMonth(String monthKey, PlatformMonthCosts costs) {
    return _monthRef(monthKey).set(costs.toMap(), SetOptions(merge: true));
  }

  /// Chiavi `yyyy-MM` per gli ultimi 12 mesi (mese corrente incluso).
  static List<String> recentMonthKeys({int count = 12}) {
    final now = DateTime.now();
    return List.generate(count, (i) {
      final d = DateTime(now.year, now.month - i, 1);
      return '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}';
    });
  }

  static String monthLabel(String monthKey) {
    final parts = monthKey.split('-');
    if (parts.length != 2) return monthKey;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    if (year == null || month == null) return monthKey;

    const names = [
      'Gennaio',
      'Febbraio',
      'Marzo',
      'Aprile',
      'Maggio',
      'Giugno',
      'Luglio',
      'Agosto',
      'Settembre',
      'Ottobre',
      'Novembre',
      'Dicembre',
    ];
    if (month < 1 || month > 12) return monthKey;
    return '${names[month - 1]} $year';
  }
}
