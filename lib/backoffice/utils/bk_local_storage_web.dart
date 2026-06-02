import 'package:web/web.dart';

String? bkLocalStorageGet(String key) => window.localStorage.getItem(key);

void bkLocalStorageSet(String key, String value) {
  window.localStorage.setItem(key, value);
}
