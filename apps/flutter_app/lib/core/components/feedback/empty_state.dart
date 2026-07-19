import 'package:flutter/material.dart';
import '../../theme/app_tokens.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({required super.key, required this.icon, required this.title, this.subtitle, this.action, this.actionLabel});

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? action;
  final String? actionLabel;

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
              decoration: BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, size: 48, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(subtitle!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
            ],
            if (action != null && actionLabel != null) ...[
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton.icon(onPressed: action, icon: const Icon(Icons.add), label: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
