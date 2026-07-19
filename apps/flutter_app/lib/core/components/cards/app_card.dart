import 'package:flutter/material.dart';
import '../../theme/app_tokens.dart';

class AppCard extends StatelessWidget {
  const AppCard({required super.key, required this.child, this.padding, this.onTap});

  final Widget child;
  final EdgeInsets? padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Padding(padding: padding ?? const EdgeInsets.all(AppSpacing.md), child: child),
      ),
    );
  }
}
