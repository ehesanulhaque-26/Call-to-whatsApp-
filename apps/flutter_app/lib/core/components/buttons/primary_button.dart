import 'package:flutter/material.dart';
import '../../theme/app_tokens.dart';

/// Premium primary button with loading state
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required super.key,
    required this.onPressed,
    required this.text,
    this.isLoading = false,
    this.icon,
    this.expand = false,
  });

  final VoidCallback? onPressed;
  final String text;
  final bool isLoading;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading)
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          )
        else if (icon != null)
          Icon(icon, size: 20),
        if (!isLoading && (icon != null || text.isNotEmpty)) ...[
          const SizedBox(width: AppSpacing.sm),
        ],
        if (!isLoading) Text(text),
      ],
    );

    return SizedBox(
      width: expand ? double.infinity : null,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        child: child,
      ),
    );
  }
}
