import fs from 'node:fs';
import path from 'node:path';

import admin from 'firebase-admin';

const [serviceAccountPath, userEmail] = process.argv.slice(2);

if (!serviceAccountPath || !userEmail) {
  console.error('Usage: node scripts/setAdminClaim.mjs <serviceAccount.json> <admin-email>');
  process.exit(1);
}

let serviceAccount;
try {
  const absolutePath = path.resolve(serviceAccountPath);
  const raw = fs.readFileSync(absolutePath, 'utf8');
  serviceAccount = JSON.parse(raw);
} catch (_) {
  console.error('Could not load service account JSON. Pass a valid absolute file path.');
  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

try {
  const user = await admin.auth().getUserByEmail(userEmail);
  await admin.auth().setCustomUserClaims(user.uid, { admin: true });
  console.log(`Admin claim set successfully for ${userEmail}.`);
  process.exit(0);
} catch (error) {
  console.error('Failed to set admin claim:', error.message);
  process.exit(1);
}
