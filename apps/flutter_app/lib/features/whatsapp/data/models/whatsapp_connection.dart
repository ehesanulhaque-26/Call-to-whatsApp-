/// WhatsApp connection state
enum WhatsAppConnectionState {
  /// No WhatsApp connected
  disconnected,

  /// Creating new connection
  creating,

  /// QR code ready for scanning
  qrReady,

  /// Waiting for scan confirmation
  connecting,

  /// Successfully connected
  connected,

  /// Error occurred
  error,
}

/// WhatsApp connection model
class WhatsAppConnection {
  WhatsAppConnection({
    this.sessionId,
    this.name,
    this.phone,
    this.businessName,
    this.profilePhoto,
    this.status,
    this.state,
    this.qrCode,
    this.lastConnected,
    this.isHealthy,
    this.errorMessage,
  });

  final String? sessionId;
  final String? name;
  final String? phone;
  final String? businessName;
  final String? profilePhoto;
  final String? status;
  final WhatsAppConnectionState? state;
  final String? qrCode;
  final DateTime? lastConnected;
  final bool? isHealthy;
  final String? errorMessage;

  bool get isConnected => state == WhatsAppConnectionState.connected;

  WhatsAppConnection copyWith({
    String? sessionId,
    String? name,
    String? phone,
    String? businessName,
    String? profilePhoto,
    String? status,
    WhatsAppConnectionState? state,
    String? qrCode,
    DateTime? lastConnected,
    bool? isHealthy,
    String? errorMessage,
  }) {
    return WhatsAppConnection(
      sessionId: sessionId ?? this.sessionId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      businessName: businessName ?? this.businessName,
      profilePhoto: profilePhoto ?? this.profilePhoto,
      status: status ?? this.status,
      state: state ?? this.state,
      qrCode: qrCode ?? this.qrCode,
      lastConnected: lastConnected ?? this.lastConnected,
      isHealthy: isHealthy ?? this.isHealthy,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  factory WhatsAppConnection.disconnected() => WhatsAppConnection(
        state: WhatsAppConnectionState.disconnected,
      );

  factory WhatsAppConnection.creating() => WhatsAppConnection(
        state: WhatsAppConnectionState.creating,
      );

  factory WhatsAppConnection.qrReady(String qrCode) => WhatsAppConnection(
        state: WhatsAppConnectionState.qrReady,
        qrCode: qrCode,
      );

  factory WhatsAppConnection.connecting() => WhatsAppConnection(
        state: WhatsAppConnectionState.connecting,
      );

  factory WhatsAppConnection.connected({
    required String sessionId,
    String? name,
    String? phone,
    String? businessName,
    String? profilePhoto,
    String? status,
    bool isHealthy = true,
    DateTime? lastConnected,
  }) =>
      WhatsAppConnection(
        sessionId: sessionId,
        name: name,
        phone: phone,
        businessName: businessName,
        profilePhoto: profilePhoto,
        status: status ?? 'Connected',
        state: WhatsAppConnectionState.connected,
        isHealthy: isHealthy,
        lastConnected: lastConnected,
      );

  factory WhatsAppConnection.error(String message) => WhatsAppConnection(
        state: WhatsAppConnectionState.error,
        errorMessage: message,
      );

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'name': name,
        'phone': phone,
        'businessName': businessName,
        'profilePhoto': profilePhoto,
        'status': status,
        'state': state?.name,
        'qrCode': qrCode,
        'lastConnected': lastConnected?.toIso8601String(),
        'isHealthy': isHealthy,
        'errorMessage': errorMessage,
      };

  factory WhatsAppConnection.fromJson(Map<String, dynamic> json) =>
      WhatsAppConnection(
        sessionId: json['sessionId'] as String?,
        name: json['name'] as String?,
        phone: json['phone'] as String?,
        businessName: json['businessName'] as String?,
        profilePhoto: json['profilePhoto'] as String?,
        status: json['status'] as String?,
        state: json['state'] != null
            ? WhatsAppConnectionState.values.firstWhere(
                (e) => e.name == json['state'],
                orElse: () => WhatsAppConnectionState.disconnected,
              )
            : null,
        qrCode: json['qrCode'] as String?,
        lastConnected: json['lastConnected'] != null
            ? DateTime.parse(json['lastConnected'] as String)
            : null,
        isHealthy: json['isHealthy'] as bool?,
        errorMessage: json['errorMessage'] as String?,
      );
}
