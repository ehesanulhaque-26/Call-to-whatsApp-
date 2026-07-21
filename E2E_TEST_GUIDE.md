# End-to-End WhatsApp Session Test Guide

## Current Verification Status

### ✅ Verified - Production Infrastructure

| Service | URL | Status | Notes |
|---------|-----|--------|-------|
| Backend | `https://call-to-whatsapp-production.up.railway.app` | ✅ Healthy | Version 1.0.0 |
| OpenWA | `https://openwa-production-d8f8.up.railway.app` | ✅ Healthy | Version 0.9.0 |
| Supabase | Connected | ✅ Healthy | Latency: 787ms |
| Swagger Docs | `/api/docs` | ✅ Available | Full API documentation |

### Backend Health Check Response
```json
{
  "status": "healthy",
  "timestamp": "2026-07-21T22:25:12.145Z",
  "version": "1.0.0",
  "uptime": 121,
  "services": {
    "database": {
      "status": "up",
      "latency": 787,
      "message": "Supabase connected"
    },
    "openwa": {
      "status": "up",
      "latency": 108,
      "message": "OpenWA Operational - https://openwa-production-d8f8.up.railway.app"
    }
  }
}
```

---

## Complete E2E Test Flow

### Step 1: User Login
```
Flutter App → Supabase Auth → JWT Token
```

**API Endpoint:** Supabase handles this internally
**Flutter Code:** `SupabaseService.auth.signIn()`

---

### Step 2: Create Session
```
Flutter → POST /api/v1/sessions/init → Backend → OpenWA
```

**API Endpoint:** `POST /api/v1/sessions/init`
**Request:**
```json
{
  "name": "my-whatsapp-session"
}
```

**Expected Response:**
```json
{
  "sessionId": "wa-xxxxx-xxxx",
  "name": "my-whatsapp-session",
  "status": "CREATING"
}
```

**Flutter Code:** `WhatsAppProvider.createSession()`

---

### Step 3: Get QR Code
```
Flutter → GET /api/v1/sessions/{sessionId}/qr → Backend → OpenWA
```

**API Endpoint:** `GET /api/v1/sessions/{sessionId}/qr`

**Expected Response:**
```json
{
  "qr": "data:image/png;base64,..."
}
```

**Flutter Code:** `WhatsAppProvider.generateQR()`

---

### Step 4: Request Pairing Code
```
Flutter → POST /api/v1/sessions/{sessionId}/pairing-code → Backend → OpenWA
```

**API Endpoint:** `POST /api/v1/sessions/{sessionId}/pairing-code`
**Request:**
```json
{
  "phoneNumber": "+919876543210"
}
```

**Expected Response (HTTP 200):**
```json
{
  "pairingCode": "ABCD-EFGH",
  "status": "PAIRING"
}
```

**Backend Logs:**
```
[OpenWAController] PAIRING CODE REQUEST - Received request for session: wa-xxxxx
[OpenWAController] PAIRING CODE REQUEST - Phone number: +919876543210
[OpenWAService] PAIRING REQUEST - Phone number pairing requested for session: wa-xxxxx
[OpenWAService] PAIRING REQUEST - Phone validated: +919876543210
[OpenWAService] PAIRING REQUEST - Calling OpenWA pairing endpoint:
[OpenWAService]   URL: https://openwa-production-d8f8.up.railway.app/api/sessions/wa-xxxxx/pairing-code
[OpenWAService]   Phone: +919876543210
[OpenWAService] PAIRING REQUEST - ✅ SUCCESS - Pairing code received: ABCD-EFGH
[OpenWAService] PAIRING REQUEST - Status: PAIRING
[OpenWAController] PAIRING CODE REQUEST - Returning pairing code: ABCD-EFGH
```

---

### Step 5: Enter Code in WhatsApp
```
User Action:
1. Open WhatsApp on phone
2. Settings > Linked Devices
3. Link a Device
4. Enter pairing code: ABCD-EFGH
```

---

### Step 6: Session Status Updates
```
Flutter ← WebSocket/SSE ← Backend ← OpenWA
```

**API Endpoint:** `GET /api/v1/sessions/{sessionId}/status`

**Expected Status Flow:**
```
CONNECTING → PAIRING → AUTHENTICATED → CONNECTED
```

**Flutter State Updates:**
```dart
phonePairingStatus: PhonePairingStatus.requestingPairingCode
  ↓
phonePairingStatus: PhonePairingStatus.pairingCodeReady
  ↓
phonePairingStatus: PhonePairingStatus.connecting
  ↓
phonePairingStatus: PhonePairingStatus.connected
```

---

### Step 7: Session Persists
```
Flutter → GET /api/v1/sessions/{sessionId}/status → Backend
```

**Expected Response:**
```json
{
  "sessionId": "wa-xxxxx",
  "name": "my-whatsapp-session",
  "status": "CONNECTED",
  "phone": "+919876543210"
}
```

---

## Available API Endpoints

### Authentication
| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| GET | `/api/v1/auth/me` | Required | Get current user |
| POST | `/api/v1/auth/verify` | Required | Verify token |

### Sessions (User)
| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| GET | `/api/v1/sessions` | Required | List user sessions |
| POST | `/api/v1/sessions/init` | Required | Initialize session |
| GET | `/api/v1/sessions/{id}` | Required | Get session |
| GET | `/api/v1/sessions/{id}/qr` | Required | Get QR code |
| POST | `/api/v1/sessions/{id}/pairing-code` | Required | Request pairing code |
| POST | `/api/v1/sessions/{id}/logout` | Required | Logout session |
| GET | `/api/v1/sessions/{id}/status` | Required | Get status |

### OpenWA Direct
| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| GET | `/api/v1/openwa/health` | Required | OpenWA health |
| POST | `/api/v1/openwa/sessions` | Required | Create session |
| GET | `/api/v1/openwa/sessions/{id}` | Required | Get session |
| POST | `/api/v1/openwa/sessions/{id}/qr` | Required | Get QR code |
| POST | `/api/v1/openwa/sessions/{id}/pairing-code` | Required | Request pairing code |

### Admin
| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| GET | `/api/v1/admin/sessions/stats` | Required (Admin) | Session stats |
| GET | `/api/v1/admin/sessions/{id}` | Required (Admin) | Get any session |

---

## Flutter Implementation

### Pairing Code Request Flow
```dart
// whatsapp_provider.dart - Line 926+
Future<String?> _requestPairingCode(String sessionId, String phoneNumber) async {
  developer.log('[WhatsAppProvider] Requesting pairing code...', name: 'PhonePairing');

  try {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/sessions/$sessionId/pairing-code',
      data: {'phoneNumber': phoneNumber},
    );

    developer.log('[WhatsAppProvider] Pairing code response status: ${response.statusCode}');
    developer.log('[WhatsAppProvider] Pairing code response data: ${response.data}');

    if (response.data != null) {
      final pairingCode = response.data!['pairingCode'] as String?;
      final status = response.data!['status'] as String?;
      
      if (pairingCode != null) {
        state = state.copyWith(
          phonePairingStatus: PhonePairingStatus.pairingCodeReady,
          pairingCode: pairingCode,
        );
        return pairingCode;
      }
    }
  } catch (e) {
    developer.log('[WhatsAppProvider] Pairing code error: $e', name: 'PhonePairing');
    // Handle error
  }
  return null;
}
```

### UI Display
```dart
// whatsapp_connect_screen.dart - Line 444+
Widget _buildPairingCodeState(String pairingCode) {
  return SingleChildScrollView(
    child: Column(
      children: [
        // Pairing Code Display
        Card(
          child: Text(
            pairingCode,  // "ABCD-EFGH"
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: 4,
            ),
          ),
        ),
        // Instructions
        // ... step by step instructions ...
      ],
    ),
  );
}
```

---

## Manual Test Checklist

### Pre-flight
- [ ] Backend is healthy: `GET /api/v1/health`
- [ ] OpenWA is healthy: `GET /api/v1/openwa/health`
- [ ] User has Supabase account
- [ ] WhatsApp app is installed on phone

### Test Steps
- [ ] 1. User logs in to Flutter app
- [ ] 2. User navigates to Sessions screen
- [ ] 3. User taps "Connect WhatsApp"
- [ ] 4. User selects "Phone Number" option
- [ ] 5. User enters phone number (+91XXXXXXXXXX)
- [ ] 6. User taps "Generate Pairing Code"
- [ ] 7. Backend creates session
- [ ] 8. Backend requests pairing code from OpenWA
- [ ] 9. Backend returns pairing code to Flutter
- [ ] 10. Flutter displays code in UI
- [ ] 11. User enters code in WhatsApp app
- [ ] 12. Session transitions to CONNECTED
- [ ] 13. User refreshes app
- [ ] 14. Session persists in list

### Verification
- [ ] QR code flow still works
- [ ] Phone pairing flow works
- [ ] Session status polling works
- [ ] Session persists after refresh
- [ ] No console errors
- [ ] No API errors in logs

---

## Log Collection

### Backend Logs (Railway Dashboard)
1. Go to Railway dashboard
2. Select `call-to-whatsapp-production` project
3. Click on backend service
4. Go to "Deployments" > "Logs"
5. Filter by: `PAIRING`

### Expected Backend Logs
```
[OpenWAController] PAIRING CODE REQUEST - Received request for session: wa-xxxxx
[OpenWAService] PAIRING REQUEST - Phone number pairing requested for session: wa-xxxxx
[OpenWAService] PAIRING REQUEST - Phone validated: +919876543210
[OpenWAService] PAIRING REQUEST - Calling OpenWA pairing endpoint:
[OpenWAService]   URL: https://openwa-production-d8f8.up.railway.app/api/sessions/wa-xxxxx/pairing-code
[OpenWAService] PAIRING REQUEST - ✅ SUCCESS - Pairing code received: ABCD-EFGH
```

### Flutter Logs (Terminal/Device)
```dart
[WhatsAppProvider] Requesting pairing code...
[WhatsAppProvider] Pairing code response status: 200
[WhatsAppProvider] Pairing code: ABCD-EFGH, status: PAIRING
```

### OpenWA Logs (Railway - if accessible)
```
[OpenWA Server] Received pairing code request for session: wa-xxxxx
[OpenWA Server] Generated pairing code: ABCD-EFGH
[OpenWA Server] Session status: PAIRING
```

---

## Known Limitations

1. **No APK Build** - Android SDK not available in current environment
2. **No Railway CLI** - Cannot access production logs directly
3. **Auth Required** - All OpenWA endpoints require valid JWT token

## Workaround for Testing

1. Build Flutter APK locally with Android SDK
2. Install on physical device
3. Use Charles Proxy or similar for log capture
4. Check Railway dashboard for backend logs
5. Test with a real WhatsApp account

---

## Success Criteria

| Criteria | Expected | Status |
|----------|----------|--------|
| Backend Health | ✅ Healthy | ✅ Verified |
| OpenWA Health | ✅ Healthy | ✅ Verified |
| API Docs | ✅ Available | ✅ Verified |
| Pairing Endpoint | ✅ Exists | ✅ Verified |
| QR Endpoint | ✅ Exists | ✅ Verified |
| Auth Guard | ✅ Protected | ✅ Verified |
| Production Config | ✅ Set | ✅ Verified |

---

## Next Steps

1. **Build APK** - Install Android SDK and build
2. **Deploy to Device** - Test with real device
3. **Collect Logs** - Capture all 3 layers
4. **Verify Flow** - Confirm end-to-end works
5. **Fix Issues** - Address any problems found
