import 'dart:async';
import 'dart:html' as html;

void initDebugListener(
    bool isMarcello,
    void Function() toggleDebug,
    ) {
  html.window.onKeyDown.listen((event) async {
    if (isMarcello &&
        event.ctrlKey &&
        event.key?.toLowerCase() == 'd') {
      final completer = Completer<void>();
      StreamSubscription<html.KeyboardEvent>? sub;

      sub = html.window.onKeyDown.listen((e) {
        if (e.key?.toLowerCase() == 'n') {
          completer.complete();
          sub?.cancel();
        }
      });

      await completer.future;
      toggleDebug();
    }
  });
}
