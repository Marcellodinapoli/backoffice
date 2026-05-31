// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';

// 🔐 Login BackOffice (email/password, NO anonimo)
import 'auth/fortress_login_page.dart';

// 🧩 Shell BackOffice
import 'backoffice/bk_shell.dart';

late FirebaseFirestore formDb;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // DEBUG essenziale
  print("✅ Firebase inizializzato");
  print("Project ID: ${DefaultFirebaseOptions.currentPlatform.projectId}");

  // Firestore istanza unica
  formDb = FirebaseFirestore.instance;

  runApp(const BackOfficeApp());
}

class BackOfficeApp extends StatelessWidget {
  const BackOfficeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Backoffice',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        cardColor: Colors.white,
      ),

      // 🔐 ENTRY POINT: login reale (email/password)
      home: const FortressLoginPage(),

      routes: {
        '/login': (_) => const FortressLoginPage(),
        '/bk-shell': (_) => const BackOfficeShell(),
      },
    );
  }
}