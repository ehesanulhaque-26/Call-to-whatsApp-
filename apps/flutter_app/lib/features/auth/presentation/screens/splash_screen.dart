import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/theme/app_tokens.dart';
import '../providers/auth_provider.dart';

/// Splash screen - app entry point
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack),
      ),
    );

    _controller.forward();
    _navigateAfterDelay();
  }

  Future<void> _navigateAfterDelay() async {
    // Wait for splash animation
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted || _hasNavigated) return;

    developer.log('[Splash] Starting navigation', name: 'Auth');

    // Check if there's a session
    final hasSession = SupabaseService.instance.currentSession != null;
    developer.log('[Splash] Has session: $hasSession', name: 'Auth');

    if (!mounted || _hasNavigated) return;

    if (hasSession) {
      // User has a session - fetch profile and navigate based on role
      developer.log('[Splash] Fetching profile...', name: 'Auth');
      
      try {
        await ref.read(authProvider.notifier).checkAuthStatus();
      } catch (e) {
        developer.log('[Splash] Profile fetch error: $e', name: 'Auth');
      }
      
      if (!mounted || _hasNavigated) return;
      
      final authState = ref.read(authProvider);
      final isAdmin = authState.role == 'admin';
      
      developer.log('[Splash] Profile loaded, role=${authState.role}, isAdmin=$isAdmin', name: 'Auth');
      
      _hasNavigated = true;
      
      if (isAdmin) {
        developer.log('[Splash] Navigating to /admin', name: 'Auth');
        context.go(AppRoutes.admin);
      } else {
        developer.log('[Splash] Navigating to /home', name: 'Auth');
        context.go(AppRoutes.home);
      }
    } else {
      // No session - go to login
      developer.log('[Splash] No session, navigating to /login', name: 'Auth');
      _hasNavigated = true;
      context.go(AppRoutes.login);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _fadeAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadius.xxl),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.chat_rounded,
                        size: 64,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'OpenWA',
                      style: AppTypography.headlineLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'SaaS Platform',
                      style: AppTypography.bodyLarge.copyWith(
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
