import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_tokens.dart';
import '../providers/whatsapp_provider.dart';

/// WhatsApp Connect Screen - Phone Number Pairing Login
class WhatsAppConnectScreen extends ConsumerStatefulWidget {
  const WhatsAppConnectScreen({super.key});

  @override
  ConsumerState<WhatsAppConnectScreen> createState() => _WhatsAppConnectScreenState();
}

class _WhatsAppConnectScreenState extends ConsumerState<WhatsAppConnectScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  
  // Country code
  String _countryCode = '+91';
  String _countryFlag = '🇮🇳';
  
  // Animation controller for success animation
  late AnimationController _successAnimationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  
  // Flag to prevent multiple navigation calls
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _successAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _successAnimationController,
        curve: Curves.elasticOut,
      ),
    );
    
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _successAnimationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _successAnimationController.dispose();
    // Reset pairing state when leaving screen
    ref.read(whatsAppProvider.notifier).resetPhonePairing();
    super.dispose();
  }

  void _onConnectionSuccess() {
    _successAnimationController.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          context.pop();
        }
      });
    });
  }

  Future<void> _onGeneratePairingCode() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Reset navigation flag for new pairing
    _hasNavigated = false;
    
    final phoneNumber = '$_countryCode${_phoneController.text}';
    
    // Start the phone pairing flow
    ref.read(whatsAppProvider.notifier).startPhonePairing(phoneNumber);
  }

  void _onConnectWithQR() {
    // Navigate to the existing WhatsApp screen with QR
    context.pop();
  }

  void _onCancelPairing() {
    // Reset navigation flag
    _hasNavigated = false;
    ref.read(whatsAppProvider.notifier).cancelPhonePairing();
  }

  void _copyPairingCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pairing code copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final whatsappState = ref.watch(whatsAppProvider);
    final pairingStatus = whatsappState.phonePairingStatus;
    final pairingCode = whatsappState.pairingCode;
    final pairingError = whatsappState.pairingError;
    final phoneNumber = whatsappState.pairingPhoneNumber;

    // Auto-navigate when connected (only once)
    if (pairingStatus == PhonePairingStatus.connected && !_hasNavigated) {
      _hasNavigated = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _onConnectionSuccess();
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect WhatsApp'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primary.withOpacity(0.1),
              Theme.of(context).scaffoldBackgroundColor,
            ],
          ),
        ),
        child: SafeArea(
          child: _buildBody(pairingStatus, pairingCode, pairingError, phoneNumber),
        ),
      ),
    );
  }

  Widget _buildBody(
    PhonePairingStatus status,
    String? pairingCode,
    String? pairingError,
    String? phoneNumber,
  ) {
    // Show success animation when connected
    if (status == PhonePairingStatus.connected) {
      return _buildSuccessState();
    }

    // Show pairing code state
    if (status == PhonePairingStatus.pairingCodeReady && pairingCode != null) {
      return _buildPairingCodeState(pairingCode);
    }

    // Show pairing in progress state
    if (status == PhonePairingStatus.pairing) {
      return _buildPairingProgressState(pairingCode);
    }

    // Show loading states
    if (status == PhonePairingStatus.preparingSession ||
        status == PhonePairingStatus.sessionReady ||
        status == PhonePairingStatus.requestingPairingCode) {
      return _buildLoadingState(status, phoneNumber);
    }

    // Show error state
    if (status == PhonePairingStatus.failed && pairingError != null) {
      return _buildErrorState(pairingError);
    }

    // Default: show connection options
    return _buildConnectionOptionsState();
  }

  Widget _buildConnectionOptionsState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.xxl),
            
            // WhatsApp Icon
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.phone_android,
                size: 60,
                color: AppColors.primary,
              ),
            ),
            
            const SizedBox(height: AppSpacing.xxl),
            
            // Title
            Text(
              'Connect using\nPhone Number',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: AppSpacing.sm),
            
            Text(
              'Link your WhatsApp account with a pairing code',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: AppSpacing.xxl),
            
            // Phone Number Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.xl),
                side: BorderSide(
                  color: AppColors.primary.withOpacity(0.2),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Country Picker
                    Row(
                      children: [
                        GestureDetector(
                          onTap: _showCountryPicker,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(_countryFlag, style: const TextStyle(fontSize: 24)),
                                const SizedBox(width: AppSpacing.sm),
                                Text(
                                  _countryCode,
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const Icon(Icons.arrow_drop_down),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        // Phone Number Input
                        Expanded(
                          child: TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              hintText: 'Phone number',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppRadius.md),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.sm,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Enter phone number';
                              }
                              if (value.length < 8) {
                                return 'Enter valid phone number';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: AppSpacing.lg),
            
            // Generate Pairing Code Button
            _PrimaryActionButton(
              onPressed: _onGeneratePairingCode,
              label: 'Generate Pairing Code',
              icon: Icons.lock_open,
              isLoading: false,
            ),
            
            const SizedBox(height: AppSpacing.xl),
            
            // Divider with OR
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Text(
                    'OR',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            
            const SizedBox(height: AppSpacing.xl),
            
            // QR Login Option
            _SecondaryActionButton(
              onPressed: _onConnectWithQR,
              label: 'Scan QR Code',
              icon: Icons.qr_code_scanner,
            ),
            
            const SizedBox(height: AppSpacing.xxl),
            
            // Help Text
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.info, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'A pairing code will be sent to your WhatsApp. Open the app to approve.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.info,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState(PhonePairingStatus status, String? phoneNumber) {
    String message;
    
    switch (status) {
      case PhonePairingStatus.preparingSession:
        message = 'Preparing session...';
        break;
      case PhonePairingStatus.sessionReady:
        message = 'Session ready, requesting code...';
        break;
      case PhonePairingStatus.requestingPairingCode:
        message = 'Generating pairing code...';
        break;
      default:
        message = 'Please wait...';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            Text(
              message,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            if (phoneNumber != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                phoneNumber,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xxl),
            TextButton(
              onPressed: _onCancelPairing,
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPairingCodeState(String pairingCode) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.xxl),
          
          // Phone Icon
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.verified_user,
              size: 50,
              color: AppColors.primary,
            ),
          ),
          
          const SizedBox(height: AppSpacing.xxl),
          
          Text(
            'Pairing Code',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: AppSpacing.lg),
          
          // Pairing Code Card
          GestureDetector(
            onTap: () => _copyPairingCode(pairingCode),
            child: Card(
              elevation: 4,
              shadowColor: AppColors.primary.withOpacity(0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.xl),
              ),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary.withOpacity(0.05),
                      AppColors.primary.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                ),
                child: Column(
                  children: [
                    // Pairing Code
                    Text(
                      pairingCode,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    // Copy hint
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.copy,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          'Tap to copy',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          const SizedBox(height: AppSpacing.xxl),
          
          // Instructions
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant.withOpacity(0.5),
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            child: Column(
              children: [
                _InstructionRow(
                  number: '1',
                  text: 'Open WhatsApp on your phone',
                ),
                const SizedBox(height: AppSpacing.md),
                _InstructionRow(
                  number: '2',
                  text: 'Go to Settings > Linked Devices',
                ),
                const SizedBox(height: AppSpacing.md),
                _InstructionRow(
                  number: '3',
                  text: 'Tap "Link a Device"',
                ),
                const SizedBox(height: AppSpacing.md),
                _InstructionRow(
                  number: '4',
                  text: 'Enter the pairing code above',
                ),
              ],
            ),
          ),
          
          const SizedBox(height: AppSpacing.lg),
          
          // Warning
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Row(
              children: [
                const Icon(Icons.timer, color: AppColors.warning, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'This code expires shortly. Complete pairing quickly.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.warning,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: AppSpacing.xxl),
          
          // Cancel Button
          TextButton(
            onPressed: _onCancelPairing,
            child: const Text('Cancel'),
          ),
          
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  Widget _buildPairingProgressState(String? pairingCode) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.xxl),
          
          // Animated Icon
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(
                    color: AppColors.primary.withOpacity(0.3),
                    strokeWidth: 2,
                  ),
                ),
                const Icon(
                  Icons.hourglass_empty,
                  size: 40,
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: AppSpacing.xxl),
          
          Text(
            'Waiting for approval...',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: AppSpacing.md),
          
          Text(
            'Check your WhatsApp app and enter the pairing code',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          
          if (pairingCode != null) ...[
            const SizedBox(height: AppSpacing.xxl),
            
            // Pairing Code Reminder
            Card(
              elevation: 0,
              color: AppColors.surfaceVariant.withOpacity(0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.key, size: 20, color: AppColors.primary),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Code: $pairingCode',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          
          const SizedBox(height: AppSpacing.xxl),
          
          // Instructions
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.info.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.check_circle, color: AppColors.success, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Pairing code sent!',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  '• Make sure WhatsApp is open on your phone\n'
                  '• Check for a notification from WhatsApp\n'
                  '• Enter the code when prompted\n'
                  '• Keep your phone connected to the internet',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: AppSpacing.xxl),
          
          // Cancel Button
          TextButton(
            onPressed: _onCancelPairing,
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                size: 50,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            Text(
              'Connection Failed',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              error,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xxl),
            _PrimaryActionButton(
              onPressed: () {
                _hasNavigated = false;
                ref.read(whatsAppProvider.notifier).resetPhonePairing();
              },
              label: 'Try Again',
              icon: Icons.refresh,
              isLoading: false,
            ),
            const SizedBox(height: AppSpacing.md),
            TextButton(
              onPressed: _onConnectWithQR,
              child: const Text('Use QR Code Instead'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessState() {
    return AnimatedBuilder(
      animation: _successAnimationController,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      size: 80,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  Text(
                    'Connected!',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Redirecting to dashboard...',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _CountryPickerSheet(
        selectedCode: _countryCode,
        selectedFlag: _countryFlag,
        onSelect: (code, flag) {
          setState(() {
            _countryCode = code;
            _countryFlag = flag;
          });
          Navigator.pop(context);
        },
      ),
    );
  }
}

/// Primary Action Button
class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({
    required this.onPressed,
    required this.label,
    required this.icon,
    required this.isLoading,
  });

  final VoidCallback onPressed;
  final String label;
  final IconData icon;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          elevation: 2,
        ),
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 22),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Secondary Action Button
class _SecondaryActionButton extends StatelessWidget {
  const _SecondaryActionButton({
    required this.onPressed,
    required this.label,
    required this.icon,
  });

  final VoidCallback onPressed;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22),
            const SizedBox(width: AppSpacing.sm),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Instruction Row
class _InstructionRow extends StatelessWidget {
  const _InstructionRow({
    required this.number,
    required this.text,
  });

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

/// Country Picker Sheet
class _CountryPickerSheet extends StatefulWidget {
  const _CountryPickerSheet({
    required this.selectedCode,
    required this.selectedFlag,
    required this.onSelect,
  });

  final String selectedCode;
  final String selectedFlag;
  final Function(String code, String flag) onSelect;

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  final _searchController = TextEditingController();
  final List<Map<String, String>> _countries = [
    {'flag': '🇮🇳', 'code': '+91', 'name': 'India'},
    {'flag': '🇺🇸', 'code': '+1', 'name': 'United States'},
    {'flag': '🇬🇧', 'code': '+44', 'name': 'United Kingdom'},
    {'flag': '🇨🇦', 'code': '+1', 'name': 'Canada'},
    {'flag': '🇦🇺', 'code': '+61', 'name': 'Australia'},
    {'flag': '🇧🇷', 'code': '+55', 'name': 'Brazil'},
    {'flag': '🇮🇩', 'code': '+62', 'name': 'Indonesia'},
    {'flag': '🇵🇰', 'code': '+92', 'name': 'Pakistan'},
    {'flag': '🇳🇬', 'code': '+234', 'name': 'Nigeria'},
    {'flag': '🇧🇩', 'code': '+880', 'name': 'Bangladesh'},
    {'flag': '🇷🇺', 'code': '+7', 'name': 'Russia'},
    {'flag': '🇯🇵', 'code': '+81', 'name': 'Japan'},
    {'flag': '🇲🇽', 'code': '+52', 'name': 'Mexico'},
    {'flag': '🇩🇪', 'code': '+49', 'name': 'Germany'},
    {'flag': '🇫🇷', 'code': '+33', 'name': 'France'},
    {'flag': '🇮🇹', 'code': '+39', 'name': 'Italy'},
    {'flag': '🇪🇸', 'code': '+34', 'name': 'Spain'},
    {'flag': '🇳🇱', 'code': '+31', 'name': 'Netherlands'},
    {'flag': '🇸🇦', 'code': '+966', 'name': 'Saudi Arabia'},
    {'flag': '🇦🇪', 'code': '+971', 'name': 'UAE'},
    {'flag': '🇸🇬', 'code': '+65', 'name': 'Singapore'},
    {'flag': '🇲🇾', 'code': '+60', 'name': 'Malaysia'},
    {'flag': '🇹🇭', 'code': '+66', 'name': 'Thailand'},
    {'flag': '🇻🇳', 'code': '+84', 'name': 'Vietnam'},
    {'flag': '🇵🇭', 'code': '+63', 'name': 'Philippines'},
    {'flag': '🇪🇬', 'code': '+20', 'name': 'Egypt'},
    {'flag': '🇰🇪', 'code': '+254', 'name': 'Kenya'},
    {'flag': '🇿🇦', 'code': '+27', 'name': 'South Africa'},
    {'flag': '🇹🇷', 'code': '+90', 'name': 'Turkey'},
    {'flag': '🇦🇷', 'code': '+54', 'name': 'Argentina'},
  ];

  List<Map<String, String>> _filteredCountries = [];

  @override
  void initState() {
    super.initState();
    _filteredCountries = _countries;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterCountries(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredCountries = _countries;
      } else {
        _filteredCountries = _countries
            .where((c) =>
                c['name']!.toLowerCase().contains(query.toLowerCase()) ||
                c['code']!.contains(query))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Column(
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(
              'Select Country',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // Search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: TextField(
              controller: _searchController,
              onChanged: _filterCountries,
              decoration: InputDecoration(
                hintText: 'Search country...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // Country List
          Expanded(
            child: ListView.builder(
              itemCount: _filteredCountries.length,
              itemBuilder: (context, index) {
                final country = _filteredCountries[index];
                final isSelected = country['code'] == widget.selectedCode;
                return ListTile(
                  leading: Text(country['flag']!, style: const TextStyle(fontSize: 24)),
                  title: Text(country['name']!),
                  subtitle: Text(country['code']!),
                  trailing: isSelected
                      ? const Icon(Icons.check, color: AppColors.primary)
                      : null,
                  selected: isSelected,
                  selectedTileColor: AppColors.primary.withOpacity(0.1),
                  onTap: () => widget.onSelect(country['code']!, country['flag']!),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
