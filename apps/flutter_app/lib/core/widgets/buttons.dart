import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';

/// Primary button with loading state
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.isLoading = false,
    this.isDisabled = false,
    this.icon,
    this.width,
  });

  final VoidCallback? onPressed;
  final String label;
  final bool isLoading;
  final bool isDisabled;
  final IconData? icon;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final isEnabled = !isDisabled && !isLoading;

    return SizedBox(
      width: width,
      height: 52,
      child: ElevatedButton(
        onPressed: isEnabled ? onPressed : null,
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Text(label),
                ],
              ),
      ),
    );
  }
}

/// Secondary/outline button with loading state
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.isLoading = false,
    this.isDisabled = false,
    this.icon,
    this.width,
  });

  final VoidCallback? onPressed;
  final String label;
  final bool isLoading;
  final bool isDisabled;
  final IconData? icon;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final isEnabled = !isDisabled && !isLoading;

    return SizedBox(
      width: width,
      height: 52,
      child: OutlinedButton(
        onPressed: isEnabled ? onPressed : null,
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Text(label),
                ],
              ),
      ),
    );
  }
}

/// Text button with loading state
class TextLoadingButton extends StatelessWidget {
  const TextLoadingButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.isLoading = false,
    this.isDisabled = false,
  });

  final VoidCallback? onPressed;
  final String label;
  final bool isLoading;
  final bool isDisabled;

  @override
  Widget build(BuildContext context) {
    final isEnabled = !isDisabled && !isLoading;

    return TextButton(
      onPressed: isEnabled ? onPressed : null,
      child: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            )
          : Text(label),
    );
  }
}
