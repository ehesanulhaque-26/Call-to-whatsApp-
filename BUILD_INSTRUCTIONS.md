# Flutter Release APK Build Instructions

## Prerequisites

Before building the release APK, you need:

1. **Supabase Project**
   - Create a project at https://supabase.com
   - Get your project URL and anon key from Settings > API

2. **Supabase Database Setup**
   - The backend expects specific tables in Supabase
   - Run the database migrations from `apps/backend/src/scripts/`

3. **Backend Deployment**
   - Backend is deployed at: `https://call-to-whatsapp-production.up.railway.app`
   - Ensure it has the correct Supabase configuration

---

## Step 1: Get Your Supabase Credentials

1. Go to https://supabase.com
2. Select your project
3. Go to **Settings** → **API**
4. Copy:
   - **Project URL** (e.g., `https://xxxxx.supabase.co`)
   - **anon/public** key

---

## Step 2: Build the Release APK

### Option A: Using Command Line

```bash
cd apps/flutter_app

flutter build apk --release \
  --dart-define=API_BASE_URL=https://call-to-whatsapp-production.up.railway.app/api/v1 \
  --dart-define=WS_URL=wss://call-to-whatsapp-production.up.railway.app/openwa \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY \
  --dart-define=APP_VERSION=1.0.0
```

### Option B: Create a Build Script

Create `build.sh` in `apps/flutter_app/`:

```bash
#!/bin/bash

# Replace these values with your actual Supabase credentials
SUPABASE_URL="https://YOUR_PROJECT.supabase.co"
SUPABASE_ANON_KEY="YOUR_ANON_KEY"

flutter build apk --release \
  --dart-define=API_BASE_URL=https://call-to-whatsapp-production.up.railway.app/api/v1 \
  --dart-define=WS_URL=wss://call-to-whatsapp-production.up.railway.app/openwa \
  --dart-define=SUPABASE_URL=$SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY \
  --dart-define=APP_VERSION=1.0.0
```

Run:
```bash
chmod +x build.sh
./build.sh
```

---

## Step 3: Locate the APK

After successful build, the APK will be at:

```
apps/flutter_app/build/app/outputs/flutter-apk/app-release.apk
```

---

## Step 4: Install on Device

### Via ADB (if device is connected via USB)
```bash
adb install apps/flutter_app/build/app/outputs/flutter-apk/app-release.apk
```

### Manual Installation
1. Transfer `app-release.apk` to your Android device
2. Enable "Install from unknown sources" in device settings
3. Open the APK file and tap "Install"

---

## Step 5: Configure Supabase Authentication

For the app to work, you need to configure Supabase Auth:

### In Supabase Dashboard:
1. Go to **Authentication** → **Settings**
2. Configure Site URL: `https://your-domain.com` (or any URL for testing)
3. Configure Redirect URLs:
   - `io.supabase.flutterquickstart://login-callback/` (default Flutter callback)
   - `https://localhost/` (for testing)

### Update App Links (Optional)
If you want deep linking, update `android/app/src/main/AndroidManifest.xml`:

```xml
<queries>
  <intent>
    <action android:name="android.intent.action.VIEW" />
    <data android:scheme="https" />
  </intent>
</queries>
```

---

## Manual Test Steps

### 1. Launch the App
- Open the installed APK
- You should see the login screen

### 2. Sign Up / Sign In
- Create an account or sign in with Supabase Auth
- The app uses Supabase for authentication

### 3. Navigate to Sessions
- After login, go to Sessions screen
- Tap "Connect WhatsApp"

### 4. Select Connection Method
- Choose **"Phone Number"** for pairing code flow
- Or **"QR Code"** for QR scan flow

### 5. Test Phone Pairing (Recommended)
1. Enter phone number: `+91XXXXXXXXXX`
2. Tap "Generate Pairing Code"
3. **Backend should:**
   - Create session
   - Request pairing code from OpenWA
   - Return pairing code to Flutter
4. **Flutter should display:**
   - Pairing code (e.g., `ABCD-EFGH`)
   - Step-by-step instructions

### 6. Enter Code in WhatsApp
1. Open WhatsApp on your phone
2. Settings → Linked Devices
3. Link a Device
4. Enter the pairing code

### 7. Verify Connection
1. Session should transition to **CONNECTED**
2. Phone number should be displayed
3. Close and reopen app
4. Session should persist in the list

---

## Troubleshooting

### "API_BASE_URL is not configured"
Build without the `--dart-define` flags. Ensure all required values are passed.

### "SUPABASE_URL is not configured"
- Verify you passed `--dart-define=SUPABASE_URL=...`
- Check for typos in the URL

### "Failed to connect to backend"
- Verify backend is running: `https://call-to-whatsapp-production.up.railway.app/api/v1/health`
- Check your internet connection

### "Authentication error"
- Verify Supabase credentials are correct
- Check Supabase dashboard for authentication settings
- Ensure Site URL and Redirect URLs are configured

### Pairing code not appearing
1. Check backend logs in Railway dashboard
2. Verify OpenWA server is running
3. Check phone number format (must include country code, e.g., `+91`)

---

## Expected Test Output

### Backend Logs (Railway Dashboard)
```
[OpenWAController] PAIRING CODE REQUEST - Received request for session: wa-xxxxx
[OpenWAService] PAIRING REQUEST - Phone validated: +91XXXXXXXXXX
[OpenWAService] PAIRING REQUEST - ✅ SUCCESS - Pairing code received: ABCD-EFGH
```

### Flutter Logs (via `flutter run` with device)
```
[WhatsAppProvider] Requesting pairing code...
[WhatsAppProvider] Pairing code response status: 200
[WhatsAppProvider] Pairing code: ABCD-EFGH, status: PAIRING
```

### UI Should Display
```
┌─────────────────────────────────┐
│         Pairing Code            │
│                                 │
│        ABCD-EFGH               │
│        (large, bold)           │
│        Tap to copy             │
│                                 │
│  1. Open WhatsApp on phone    │
│  2. Settings > Linked Devices  │
│  3. Link a Device             │
│  4. Enter pairing code        │
│                                 │
│  ⚠ Code expires shortly        │
└─────────────────────────────────┘
```

---

## Build Commands Reference

| Build Type | Command |
|------------|---------|
| Debug APK | `flutter build apk --debug` |
| Release APK | `flutter build apk --release` |
| Split APK (smaller) | `flutter build apk --release --split-per-abi` |
| With metrics | `flutter build apk --release --pub` |

---

## APK Location

After build:
```
apps/flutter_app/build/app/outputs/flutter-apk/
├── app-armeabi-v7a-release.apk  (ARM 32-bit)
├── app-arm64-v8a-release.apk     (ARM 64-bit)
├── app-x86_64-release.apk       (x86 64-bit)
└── app-release.apk               (Universal)
```

For testing, use `app-release.apk` (universal) or the specific ABI for your device.

---

## Next Steps

After successful testing:
1. [ ] Share APK with stakeholders
2. [ ] Deploy to Play Store (if needed)
3. [ ] Monitor backend logs during testing
4. [ ] Collect user feedback
5. [ ] Fix any issues discovered
