const functions = require("firebase-functions");
const admin = require("firebase-admin");

// ---------------------------------------------------------
//  INIZIALIZZAZIONE CORRETTA (PROGETTO CREDITFORM)
// ---------------------------------------------------------
admin.initializeApp({
  credential: admin.credential.cert(require("./serviceAccountKey.json")),
  databaseURL: "https://creditform-d505d.firebaseio.com"
});

/* -------------------------------------------------------
   📩 NOTIFICA LOGIN (CODICE GIÀ ESISTENTE — NON TOCCATO)
---------------------------------------------------------*/
exports.sendLoginNotification = functions.firestore
  .document("pendingLogins/currentLogin")
  .onWrite(async (change, context) => {
    const data = change.after.data();

    if (!data) {
      console.log("❌ Documento eliminato, nessuna notifica");
      return null;
    }

    if (data.confirmed === false) {
      console.log("📩 Nuova richiesta di login → invio notifica...");

      try {
        const devicesSnap = await admin.firestore().collection("devices").get();
        if (devicesSnap.empty) {
          console.log("⚠️ Nessun device registrato");
          return null;
        }

        const tokens = devicesSnap.docs
          .map((doc) => doc.data().token)
          .filter(Boolean);

        if (tokens.length === 0) {
          console.log("⚠️ Nessun token valido");
          return null;
        }

        const message = {
          notification: {
            title: "Nuova richiesta di accesso",
            body: "Conferma l’accesso al BackOffice",
          },
          data: { type: "login_request" },
          tokens: tokens,
        };

        const response = await admin.messaging().sendMulticast(message);

        console.log("✅ Notifiche inviate:", response.successCount);
        if (response.failureCount > 0) {
          console.log("❌ Errori:", response.responses.filter((r) => !r.success));
        }
      } catch (error) {
        console.error("❌ Errore invio notifica:", error);
      }
    }

    return null;
  });

/* -------------------------------------------------------
   🧹 ELIMINAZIONE COMPLETA UTENTE (FUNZIONANTE)
---------------------------------------------------------*/
exports.deleteUserCompletely = functions.https.onCall(async (data, context) => {
  const uid = data.uid;

  if (!uid) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "UID mancante."
    );
  }

  // ❗ Solo gli admin possono usarla
  if (!context.auth || context.auth.token.admin !== true) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Non hai i permessi per eseguire questa operazione."
    );
  }

  try {
    console.log("🧹 Eliminazione completa per UID:", uid);

    // 1️⃣ Cancella utente da AUTH (creditform-d505d)
    await admin.auth().deleteUser(uid);
    console.log("✔️ Utente eliminato da Firebase Auth");

    // 2️⃣ Cancella documento USERS
    await admin.firestore().collection("users").doc(uid).delete();
    console.log("✔️ Documento users/{uid} eliminato");

    // 3️⃣ Cancella PROGRESSI
    await admin.firestore().collection("userProgress").doc(uid).delete().catch(() => {});
    console.log("✔️ Progressi eliminati");

    return { success: true };
  } catch (error) {
    console.error("❌ Errore eliminazione completa:", error);
    throw new functions.https.HttpsError("internal", "Errore durante l’eliminazione.");
  }
});
