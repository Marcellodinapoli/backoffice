// lib/firebase_options.dart
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      default:
        throw UnsupportedError(
          'Configurazione Firebase non disponibile per questa piattaforma.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: "AIzaSyDvg-vsDo-8sFzo6jVbeUWrRPEyFreO32I",
    authDomain: "creditform-d505d.firebaseapp.com",
    projectId: "creditform-d505d",
    storageBucket: "creditform-d505d.firebasestorage.app", // ✅ CORRETTO
    messagingSenderId: "418457726672",
    appId: "1:418457726672:web:4d0d18604a93fbd93f8d5",
  );

  static const FirebaseOptions android = web;
  static const FirebaseOptions ios = web;
  static const FirebaseOptions macos = web;
  static const FirebaseOptions windows = web;
}
