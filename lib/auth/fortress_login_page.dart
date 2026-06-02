// lib/auth/fortress_login_page.dart

// -----------------------------------------------------------------------------
// IMPORT
// -----------------------------------------------------------------------------
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../backoffice/bk_shell.dart';
import '../main.dart';

// ✅ IMPORT CONDIZIONALE (web/mobile)
import '../debug/debug_key_listener_stub.dart'
if (dart.library.html) '../debug/debug_key_listener_web.dart';

// -----------------------------------------------------------------------------
// PAGE
// -----------------------------------------------------------------------------
class FortressLoginPage extends StatefulWidget {
  const FortressLoginPage({super.key});

  @override
  State<FortressLoginPage> createState() => _FortressLoginPageState();
}

class _FortressLoginPageState extends State<FortressLoginPage> {
  // ---------------------------------------------------------------------------
  // STATE
  // ---------------------------------------------------------------------------
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  DocumentReference<Map<String, dynamic>>? _sessionRef;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sessionSub;
  Timer? _timer;

  bool _waitingConfirmation = false;

  String _debugInfo = "";
  bool _showDebug = false;
  bool _isMarcello = false;

  // ---------------------------------------------------------------------------
  // LIFECYCLE
  // ---------------------------------------------------------------------------
  @override
  void initState() {
    super.initState();

    initDebugListener(_isMarcello, () {
      if (!mounted) return;
      setState(() {
        _showDebug = !_showDebug;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sessionSub?.cancel();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // SERVICES - LOGIN
  // ---------------------------------------------------------------------------
  Future<void> _doLogin() async {
    if (!mounted) return;

    setState(() {
      _debugInfo = "🔄 Login in corso...\n";
      _showDebug = false;
    });

    try {
      final firebaseApp = Firebase.app();
      final opts = firebaseApp.options;

      _debugInfo +=
      "🌍 Firebase collegato a:\nApp name: ${firebaseApp.name}\nProject: ${opts.projectId}\nApp ID: ${opts.appId}\nAPI Key: ${opts.apiKey}\n\n";

      final userCredential =
      await FirebaseAuth.instanceFor(app: firebaseApp)
          .signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );

      if (!mounted) return;

      final user = userCredential.user;
      if (user == null) {
        setState(() {
          _debugInfo += "❌ Login fallito: nessun utente restituito\n";
          _showDebug = true;
        });
        return;
      }

      _isMarcello =
          user.email?.toLowerCase() == "dinapoli.marcello@gmail.com";

      final idTokenResult = await user.getIdTokenResult(true);
      final rawToken = await user.getIdToken(true);

      if (!mounted) return;

      String decodedPayload = "";
      if (rawToken != null) {
        try {
          final parts = rawToken.split(".");
          if (parts.length > 1) {
            decodedPayload = utf8.decode(
              base64Url.decode(base64Url.normalize(parts[1])),
            );
          }
        } catch (e) {
          decodedPayload = "❌ Errore decodifica token: $e";
        }
      }

      String firestoreCheck = "";
      try {
        await FirebaseFirestore.instance
            .collection("test")
            .doc("ping")
            .get();
        firestoreCheck = "✅ Accesso Firestore OK";
      } on FirebaseException catch (e) {
        firestoreCheck = "❌ Firestore errore: ${e.code}";
      } catch (e) {
        firestoreCheck = "❌ Firestore errore generico: $e";
      }

      final buffer = StringBuffer();
      buffer.writeln(_debugInfo);
      buffer.writeln("✅ Login riuscito");
      buffer.writeln("👤 UID: ${user.uid}");
      buffer.writeln("📧 Email: ${user.email}");
      buffer.writeln("✔️ Email verificata: ${user.emailVerified}");
      buffer.writeln("🕒 Ultimo login: ${user.metadata.lastSignInTime}");
      buffer.writeln("📅 Creato il: ${user.metadata.creationTime}");
      buffer.writeln("");
      buffer.writeln("🔐 Claims: ${idTokenResult.claims}");
      buffer.writeln(idTokenResult.claims?['admin'] == true
          ? "🎉 Utente è ADMIN"
          : "⛔ Utente NON è admin o token non aggiornato");
      buffer.writeln("");
      buffer.writeln(firestoreCheck);
      buffer.writeln("");
      buffer.writeln("🪪 Token decodificato (payload):");
      buffer.writeln(decodedPayload);

      if (!mounted) return;

      setState(() {
        _debugInfo = buffer.toString();
        _showDebug =
            _isMarcello && idTokenResult.claims?['admin'] != true;
      });

      if (idTokenResult.claims?['admin'] == true) {
        await _createPendingLogin(user);
        if (!mounted) return;

        setState(() {
          _waitingConfirmation = true;
        });
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String msg = "❌ Errore login: ${e.code}";
      if (e.code == "wrong-password") msg = "❌ Password errata";
      if (e.code == "user-not-found") msg = "❌ Utente non trovato";
      if (e.code == "user-disabled") msg = "❌ Account disabilitato";
      if (e.code == "invalid-api-key") msg = "❌ API Key non valida";
      if (e.code == "operation-not-allowed") {
        msg = "❌ Metodo di login non abilitato";
      }

      setState(() {
        _debugInfo = msg;
        _showDebug = _isMarcello;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _debugInfo = "❌ Errore login generico: $e";
        _showDebug = _isMarcello;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // SERVICES - PENDING LOGIN
  // ---------------------------------------------------------------------------
  Future<void> _createPendingLogin(User user) async {
    try {
      final doc = formDb.collection("pendingLogins").doc(user.uid);

      await doc.set({
        "uid": user.uid,
        "email": user.email,
        "confirmed": "pending",
        "createdAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _sessionRef = doc;

      _sessionSub?.cancel();

      _sessionSub = _sessionRef!.snapshots().listen((snap) async {
        if (!mounted) return;
        if (!snap.exists) return;

        final data = snap.data();
        final status = data?['confirmed'];

        if (status == "approved") {
          final refreshedUser =
              FirebaseAuth.instanceFor(app: Firebase.app()).currentUser;

          if (refreshedUser != null) {
            final token =
            await refreshedUser.getIdTokenResult(true);

            if (!mounted) return;

            if (token.claims?['admin'] == true) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => const BackOfficeShell(),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("❌ Non sei abilitato come admin"),
                ),
              );
            }
          }
        } else if (status == "denied") {
          if (!mounted) return;

          setState(() {
            _waitingConfirmation = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  "❌ Accesso negato dall’app Sicurezza"),
            ),
          );
        }
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _debugInfo =
        "❌ Errore creazione pendingLogin: $e";
        _showDebug = _isMarcello;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 800),
          decoration: BoxDecoration(
            color: Colors.blueGrey.shade800.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(20),
          ),
          child: _waitingConfirmation
              ? Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                "assets/icons/shield_admin.png",
                width: 200,
                height: 200,
              ),
              const SizedBox(width: 40),
              const Text(
                "Attendi conferma sull'app Sicurezza...",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                ),
              ),
            ],
          )
              : Row(
            mainAxisAlignment:
            MainAxisAlignment.center,
            children: [
              Image.asset(
                "assets/icons/shield_admin.png",
                width: 150,
                height: 150,
              ),
              const SizedBox(width: 40),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Accesso Admin",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _emailCtrl,
                      decoration:
                      const InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        labelText: "Email",
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passCtrl,
                      obscureText: true,
                      decoration:
                      const InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        labelText: "Password",
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _doLogin,
                      child:
                      const Text("Accedi"),
                    ),
                    if (_showDebug &&
                        _debugInfo.isNotEmpty &&
                        _isMarcello) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding:
                        const EdgeInsets.all(
                            12),
                        height: 280,
                        decoration:
                        BoxDecoration(
                          color:
                          Colors.black87,
                          borderRadius:
                          BorderRadius
                              .circular(8),
                        ),
                        child:
                        SingleChildScrollView(
                          child: Text(
                            _debugInfo,
                            style:
                            const TextStyle(
                              fontFamily:
                              "monospace",
                              color: Colors
                                  .greenAccent,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
