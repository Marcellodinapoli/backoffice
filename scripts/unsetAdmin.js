const admin = require("firebase-admin");

// 🔑 Carica la chiave di servizio
const serviceAccount = require("./serviceAccountKey.json");

// 🔹 Inizializza l'admin SDK
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

// 🔹 Funzione per rimuovere admin = true da un utente
async function unsetAdmin(uid) {
  try {
    await admin.auth().setCustomUserClaims(uid, { admin: false });
    console.log(`✅ L'utente con UID: ${uid} NON è più ADMIN`);
  } catch (error) {
    console.error("❌ Errore nel rimuovere admin:", error);
  }
}

// 🔹 Passa UID da terminale
const uid = process.argv[2];
if (!uid) {
  console.error("❌ Devi passare l'UID:  node unsetAdmin.js <UID>");
  process.exit(1);
}

unsetAdmin(uid);
