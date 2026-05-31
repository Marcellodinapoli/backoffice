// ✅ setAdmin.js — Gestione ruoli admin su Firebase

const admin = require("firebase-admin");
const path = require("path");

// 🔑 Carica in modo sicuro la chiave di servizio
const serviceAccountPath = path.resolve(__dirname, "serviceAccountKey.json");
const serviceAccount = require(serviceAccountPath);

// 📌 Log progetto
console.log("🔍 Sto usando il progetto Firebase:", serviceAccount.project_id);

// 🔹 Inizializza l'admin SDK (evita doppia inizializzazione)
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
}

// 🔹 Funzione per assegnare ruolo ADMIN
async function setAdmin(uid) {
  try {
    await admin.auth().setCustomUserClaims(uid, { admin: true });
    console.log(`✅ L'utente con UID: ${uid} ora è ADMIN`);
  } catch (error) {
    console.error("❌ Errore nel settare admin:", error.message);
  }
}

// 🔹 Funzione per rimuovere ruolo ADMIN
async function unsetAdmin(uid) {
  try {
    await admin.auth().setCustomUserClaims(uid, { admin: false });
    console.log(`✅ L'utente con UID: ${uid} NON è più ADMIN`);
  } catch (error) {
    console.error("❌ Errore nel rimuovere admin:", error.message);
  }
}

// 🔹 Funzione per leggere dati utente e claims
async function getUser(uid) {
  try {
    const user = await admin.auth().getUser(uid);
    console.log("✅ Utente trovato:");
    console.log("📧 Email:", user.email);
    console.log("🆔 UID:", user.uid);
    console.log("🏷️ Claims:", user.customClaims || {});
  } catch (error) {
    console.error("❌ Errore nel recuperare l'utente:", error.message);
  }
}

// 🔹 Gestione parametri CLI
const [,, action, uid] = process.argv;

if (!action || !uid) {
  console.error("\n❌ Uso corretto:");
  console.error("   node setAdmin.js <azione> <UID>");
  console.error("   Azioni disponibili: set | unset | get\n");
  process.exit(1);
}

(async () => {
  switch (action) {
    case "set":
      await setAdmin(uid);
      break;
    case "unset":
      await unsetAdmin(uid);
      break;
    case "get":
      await getUser(uid);
      break;
    default:
      console.error("❌ Azione non valida. Usa: set | unset | get");
      process.exit(1);
  }
})();
