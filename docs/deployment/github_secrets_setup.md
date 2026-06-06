GitHub Secrets Setup Guide

Go to: GitHub repo → Settings → Secrets and variables → Actions → New secret

Add ALL of the following secrets:

Firebase secrets (used by admin portal deploy + CI)

| Secret name | Where to get it |
|---|---|
| VITE_FIREBASE_API_KEY | Firebase Console → Project Settings → General |
| VITE_FIREBASE_AUTH_DOMAIN | Same — format: your-project.firebaseapp.com |
| VITE_FIREBASE_DATABASE_URL | Realtime Database → Data tab → URL at top |
| VITE_FIREBASE_PROJECT_ID | Project Settings → General |
| VITE_FIREBASE_STORAGE_BUCKET | Project Settings → General |
| VITE_FIREBASE_MESSAGING_SENDER_ID | Project Settings → General |
| VITE_FIREBASE_APP_ID | Project Settings → General → Your apps |
| VITE_COLLEGE_ID | e.g. kec |
| FIREBASE_SERVICE_ACCOUNT | Firebase Console → Project Settings → Service accounts → Generate new private key (paste entire JSON) |

Android signing secrets (used by release APK build)

| Secret name | How to create |
|---|---|
| KEYSTORE_BASE64 | base64 -i your-release.keystore — paste output |
| KEY_ALIAS | The alias you used when creating the keystore |
| KEY_PASSWORD | Key password |
| STORE_PASSWORD | Keystore password |

Creating a keystore (one-time):

```bash
keytool -genkey -v \
  -keystore release.keystore \
  -alias attendance \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000
```

Then encode it:

```bash
base64 -i release.keystore | pbcopy   # macOS — pastes to clipboard
base64 -i release.keystore            # Linux — copy the output
```

Paste that output as the KEYSTORE_BASE64 secret value.

Triggering a release

```bash
git tag v1.0.0
git push origin v1.0.0
```

GitHub Actions will:

- Run CI (analyze + admin build)
- Build 3 APKs in parallel (kec, psg, cbe)
- Create a GitHub Release with all APKs attached
- Deploy admin portal to Firebase Hosting
