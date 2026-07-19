import 'package:flutter/material.dart';
import '../../theme/app_tokens.dart';

class ErrorState extends StatelessWidget {
  const ErrorState({required super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Something went wrong', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            Text(message, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Try Again')),
            ],
          ],
        ),
      ),
    );
  }
}
