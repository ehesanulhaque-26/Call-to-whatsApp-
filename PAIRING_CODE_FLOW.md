# Pairing Code Flow Demonstration

This document demonstrates the complete pairing code flow from Flutter UI to backend and back.

---

## Complete Request/Response Flow

### 1. Flutter App: User Initiates Pairing

**User Action:**
- Opens `WhatsAppConnectScreen`
- Enters phone number: `+919876543210`
- Taps "Generate Pairing Code"

**Flutter Code (whatsapp_provider.dart):**
```dart
// Line 926-934
Future<String?> _requestPairingCode(String sessionId, String phoneNumber) async {
  developer.log('[WhatsAppProvider] Requesting pairing code...', name: 'PhonePairing');

  final response = await _apiClient.post<Map<String, dynamic>>(
    '/openwa/sessions/$sessionId/pairing-code',
    data: {'phoneNumber': phoneNumber},
  );
  // ...
}
```

**Flutter Console Output:**
```
[WhatsAppProvider] Requesting pairing code for session: wa-12345, phone: +919876543210
```

---

### 2. API Request: Flutter → Backend

**HTTP Request:**
```
POST /api/v1/openwa/sessions/wa-12345/pairing-code
Content-Type: application/json
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
Accept: application/json

{
  "phoneNumber": "+919876543210"
}
```

---

### 3. Backend Controller (openwa.controller.ts)

**Endpoint Definition (Line 323-456):**
```typescript
@Post('sessions/:sessionId/pairing-code')
@HttpCode(HttpStatus.OK)
@ApiOperation({ summary: 'Request pairing code for phone number authentication' })
async requestPairingCode(
  @Param('sessionId') sessionId: string,
  @Body() body: RequestPairingCodeDto,
) {
  console.log(
    `[OpenWA Controller] PAIRING CODE REQUEST - Received request for session: ${sessionId}`,
  );
  console.log(`[OpenWA Controller] PAIRING CODE REQUEST - Phone number: ${body.phoneNumber}`);

  const result = await this.openWAService.requestPairingCode(sessionId, body.phoneNumber);

  console.log(
    `[OpenWA Controller] PAIRING CODE REQUEST - Returning pairing code: ${result.pairingCode}`,
  );

  return result;
}
```

**Backend Console Logs:**
```
[OpenWA Controller] PAIRING CODE REQUEST - Received request for session: wa-12345
[OpenWA Controller] PAIRING CODE REQUEST - Phone number: +919876543210
```

---

### 4. Backend Service (openwa.service.ts)

**Service Method (Line 492-535):**
```typescript
async requestPairingCode(
  sessionId: string,
  phoneNumber: string,
): Promise<FlutterPairingCodeResponse> {
  this.logger.warn(
    `[OpenWA Service] PAIRING REQUEST - Phone number pairing requested for session: ${sessionId}`,
  );
  this.logger.warn(`[OpenWA Service] PAIRING REQUEST - Phone validated: ${phoneNumber}`);

  // Validate phone number format
  const cleanedPhone = phoneNumber.replace(/[\s\-()]/g, '');
  if (!cleanedPhone.match(/^\+?\d{10,15}$/)) {
    this.logger.error(
      `[OpenWA Service] PAIRING REQUEST - Invalid phone number format: ${phoneNumber}`,
    );
    throw new HttpException('Invalid phone number format', HttpStatus.BAD_REQUEST);
  }

  // Normalize phone number to ensure it starts with +
  const normalizedPhone = cleanedPhone.startsWith('+') ? cleanedPhone : `+${cleanedPhone}`;

  this.logger.warn(
    `[OpenWA Service] PAIRING REQUEST - Calling OpenWA pairing endpoint for phone: ${normalizedPhone}`,
  );

  try {
    // Call OpenWA pairing endpoint
    const response = await this.request<OpenWAPairingCodeResponse>(
      'POST',
      `/api/sessions/${sessionId}/pairing-code`,
      { phoneNumber: normalizedPhone },
    );

    this.logger.warn(
      `[OpenWA Service] PAIRING REQUEST - Pairing code received: ${response.pairingCode}`,
    );
    this.logger.warn(`[OpenWA Service] PAIRING REQUEST - Status: ${response.status}`);

    // Return clean Flutter contract
    return {
      pairingCode: response.pairingCode,
      status: response.status,
    };
  } catch (error) {
    // Error handling...
  }
}
```

**Backend Console Logs:**
```
[OpenWA Service] PAIRING REQUEST - Phone number pairing requested for session: wa-12345
[OpenWA Service] PAIRING REQUEST - Phone validated: +919876543210
[OpenWA Service] PAIRING REQUEST - Calling OpenWA pairing endpoint for phone: +919876543210
[OpenWA Service] PAIRING REQUEST - Pairing code received: ABCD-EFGH
[OpenWA Service] PAIRING REQUEST - Status: PAIRING
```

---

### 5. Backend Response (HTTP 200)

**Response Body:**
```json
{
  "pairingCode": "ABCD-EFGH",
  "status": "PAIRING"
}
```

---

### 6. Flutter Receives Response

**Flutter Code (whatsapp_provider.dart):**
```dart
// Line 930-950
final response = await _apiClient.post<Map<String, dynamic>>(
  '/openwa/sessions/$sessionId/pairing-code',
  data: {'phoneNumber': phoneNumber},
);

developer.log('[WhatsAppProvider] Pairing code response status: ${response.statusCode}');
developer.log('[WhatsAppProvider] Pairing code response data: ${response.data}');

if (response.data != null) {
  final pairingCode = response.data!['pairingCode'] as String?;
  final status = response.data!['status'] as String?;
  
  developer.log('[WhatsAppProvider] Pairing code: $pairingCode, status: $status');
  
  if (pairingCode != null) {
    state = state.copyWith(
      phonePairingStatus: PhonePairingStatus.pairingCodeReady,
      pairingCode: pairingCode,
    );
    return pairingCode;
  }
}
```

**Flutter Console Output:**
```
[WhatsAppProvider] Pairing code response status: 200
[WhatsAppProvider] Pairing code response data: {pairingCode: ABCD-EFGH, status: PAIRING}
[WhatsAppProvider] Pairing code: ABCD-EFGH, status: PAIRING
```

---

### 7. Flutter UI Updates

**State Change:**
- `phonePairingStatus` → `PhonePairingStatus.pairingCodeReady`
- `pairingCode` → `"ABCD-EFGH"`

**UI Render (whatsapp_connect_screen.dart):**
```dart
// Line 164-165: State triggers pairing code display
if (status == PhonePairingStatus.pairingCodeReady && pairingCode != null) {
  return _buildPairingCodeState(pairingCode);
}

// Line 444-607: Pairing code UI
Widget _buildPairingCodeState(String pairingCode) {
  return SingleChildScrollView(
    // ...
    child: Column(
      children: [
        // ... icons and text ...
        
        // Pairing Code Card
        Card(
          child: Container(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Column(
              children: [
                // Pairing Code Display
                Text(
                  pairingCode,  // <-- "ABCD-EFGH"
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                    color: AppColors.primary,
                  ),
                ),
                // Copy hint
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.copy, size: 16),
                    Text('Tap to copy'),
                  ],
                ),
              ],
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

**Flutter Console Output:**
```
[WhatsAppProvider] Pairing code: ABCD-EFGH, status: PAIRING
```

---

## Visual Representation of UI

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│     ┌─────────────────────────────────────────────┐    │
│     │                                             │    │
│     │              ✓ Verified                     │    │
│     │                                             │    │
│     │            Pairing Code                      │    │
│     │                                             │    │
│     │   ┌───────────────────────────────────┐     │    │
│     │   │                                   │     │    │
│     │   │          ABCD-EFGH                 │     │    │
│     │   │       (large, bold text)          │     │    │
│     │   │                                   │     │    │
│     │   │          📋 Tap to copy            │     │    │
│     │   └───────────────────────────────────┘     │    │
│     │                                             │    │
│     │   1. Open WhatsApp on your phone           │    │
│     │   2. Go to Settings > Linked Devices        │    │
│     │   3. Tap "Link a Device"                   │    │
│     │   4. Enter the pairing code above           │    │
│     │                                             │    │
│     │   ⚠ This code expires shortly              │    │
│     │                                             │    │
│     │              [Cancel]                       │    │
│     │                                             │    │
│     └─────────────────────────────────────────────┘    │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## Complete Console Log Sequence

### Backend (NestJS Console)
```
[Nest] 12345 - 07/21/2026, 10:30:00 PM   WARN [OpenWAController]
[OpenWA Controller] PAIRING CODE REQUEST - Received request for session: wa-12345
[OpenWA Controller] PAIRING CODE REQUEST - Phone number: +919876543210

[Nest] 12345 - 07/21/2026, 10:30:00 PM   WARN [OpenWAService]
[OpenWA Service] PAIRING REQUEST - Phone number pairing requested for session: wa-12345
[OpenWA Service] PAIRING REQUEST - Phone validated: +919876543210
[OpenWA Service] PAIRING REQUEST - Calling OpenWA pairing endpoint for phone: +919876543210
[OpenWA Service] PAIRING REQUEST - Pairing code received: ABCD-EFGH
[OpenWA Service] PAIRING REQUEST - Status: PAIRING

[Nest] 12345 - 07/21/2026, 10:30:00 PM   WARN [OpenWAController]
[OpenWA Controller] PAIRING CODE REQUEST - Returning pairing code: ABCD-EFGH
```

### Flutter (Dart Developer Console)
```
[WhatsAppProvider] Requesting pairing code for session: wa-12345, phone: +919876543210
[WhatsAppProvider] Pairing code response status: 200
[WhatsAppProvider] Pairing code response data: {pairingCode: ABCD-EFGH, status: PAIRING}
[WhatsAppProvider] Pairing code: ABCD-EFGH, status: PAIRING
```

---

## Error Scenarios

### Invalid Phone Number (HTTP 400)
```
[OpenWA Service] PAIRING REQUEST - Invalid phone number format: invalid
```
→ Flutter shows: "Invalid phone number format"

### Session Not Found (HTTP 404)
```
[OpenWA Service] PAIRING REQUEST - Session not found: invalid-session
```
→ Flutter shows: "Session not found"

### Session Already Connected (HTTP 409)
```
[OpenWA Service] PAIRING REQUEST - Session already connected: wa-connected
```
→ Flutter shows: "Session is already connected. Please disconnect first."

### OpenWA Unavailable (HTTP 503)
```
[OpenWA Service] PAIRING REQUEST - OpenWA server unavailable
```
→ Flutter shows: "OpenWA server unavailable"

---

## Summary

| Step | Component | Action | Log Output |
|------|-----------|--------|------------|
| 1 | Flutter | User taps "Generate Pairing Code" | Requesting pairing code... |
| 2 | Flutter | API call initiated | POST /openwa/sessions/.../pairing-code |
| 3 | Backend | Controller receives request | PAIRING CODE REQUEST - Received |
| 4 | Backend | Service validates phone | Phone validated: +919876543210 |
| 5 | Backend | Calls OpenWA server | Calling OpenWA pairing endpoint |
| 6 | Backend | Receives code | Pairing code received: ABCD-EFGH |
| 7 | Backend | Returns to Flutter | HTTP 200, { pairingCode: "ABCD-EFGH" } |
| 8 | Flutter | Receives response | Pairing code: ABCD-EFGH |
| 9 | Flutter | Updates UI state | phonePairingStatus: pairingCodeReady |
| 10 | Flutter | Renders UI | Displaying "ABCD-EFGH" in card |

---

## Code References

- **Flutter Provider**: `apps/flutter_app/lib/features/whatsapp/presentation/providers/whatsapp_provider.dart` (Line 926-1004)
- **Flutter Screen**: `apps/flutter_app/lib/features/whatsapp/presentation/screens/whatsapp_connect_screen.dart` (Line 444-607)
- **Backend Controller**: `apps/backend/src/modules/openwa/openwa.controller.ts` (Line 323-456)
- **Backend Service**: `apps/backend/src/modules/openwa/openwa.service.ts` (Line 492-535)
- **DTO**: `apps/backend/src/modules/openwa/dto/request-pairing-code.dto.ts`
