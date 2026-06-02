// ignore_for_file: avoid_print

// lib/main_debug.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inizializza Firebase con le opzioni di creditform_web
  final app = await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ✅ Log di debug per confermare che usa il progetto giusto
  print("🔍 Firebase inizializzato:");
  print("   ProjectId: ${app.options.projectId}");
  print("   AppId: ${app.options.appId}");
  print("   ApiKey: ${app.options.apiKey}");
  print("   StorageBucket: ${app.options.storageBucket}");
  print("   MessagingSenderId: ${app.options.messagingSenderId}");
  print("   AuthDomain: ${app.options.authDomain}");

  runApp(const DebugApp());
}

class DebugApp extends StatelessWidget {
  const DebugApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Firebase Debug',
      home: Scaffold(
        appBar: AppBar(title: const Text("Firebase Debug")),
        body: const Center(
          child: Text(
            "Se vedi questa schermata senza errori,\n"
                "Firebase è configurato correttamente ✅",
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
