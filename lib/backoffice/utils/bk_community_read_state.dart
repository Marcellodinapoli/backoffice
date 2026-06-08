import 'dart:convert';

import 'bk_local_storage.dart';

/// Stato lettura discussioni community (allineato a credit-calc-store).
abstract final class BkCommunityReadState {
  static const _storageKey = 'communityTopicsLastSeen';

  static Map<String, int> getTopicsLastSeen() {
    final raw = bkLocalStorageGet(_storageKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return decoded.map(
        (key, value) => MapEntry(key.toString(), (value as num).toInt()),
      );
    } catch (_) {
      return {};
    }
  }

  static int getTopicLastSeenMs(String topicId) {
    return getTopicsLastSeen()[topicId] ?? 0;
  }

  static void setTopicLastSeenMs(String topicId, int ms) {
    final topics = getTopicsLastSeen();
    topics[topicId] = ms;
    bkLocalStorageSet(_storageKey, jsonEncode(topics));
  }

  static void ensureTopicInitialized(String topicId, int defaultLastSeenMs) {
    final topics = getTopicsLastSeen();
    if (topics.containsKey(topicId)) return;
    topics[topicId] = defaultLastSeenMs;
    bkLocalStorageSet(_storageKey, jsonEncode(topics));
  }
}
