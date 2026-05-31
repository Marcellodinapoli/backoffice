// scripts/setSecurityDevice.js
const admin = require("firebase-admin");

// Inizializza con la service account key del tuo progetto
admin.initializeApp({
  credential: admin.credential.cert(require("./serviceAccountKey.json")),
});

async function setSecurityDevice(uid) {
  try {
    await admin.auth().setCustomUserClaims(uid, { security_device: true });
    console.log(`✅ Utente con UID ${uid} ora ha claim security_device:true`);
  } catch (error) {
    console.error("❌ Errore:", error);
  }
}

async function getClaims(uid) {
  try {
    const user = await admin.auth().getUser(uid);
    console.log("🔍 Claims attuali:", user.customClaims);
  } catch (error) {
    console.error("❌ Errore:", error);
  }
}

const action = process.argv[2];
const uid = process.argv[3];

if (!action || !uid) {
  console.log("❌ Usa: node setSecurityDevice.js <set|get> <UID>");
  process.exit(1);
}

if (action === "set") {
  setSecurityDevice(uid);
} else if (action === "get") {
  getClaims(uid);
} else {
  console.log("❌ Azione non valida. Usa: set oppure get");
}
