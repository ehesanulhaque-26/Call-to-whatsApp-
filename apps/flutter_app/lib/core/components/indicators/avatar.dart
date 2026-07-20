import 'package:flutter/material.dart';
import '../../theme/app_tokens.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    required super.key,
    required this.name,
    this.imageUrl,
    this.size = 40,
  });

  final String name;
  final String? imageUrl;
  final double size;

  String _getInitials() {
    final parts = name.split(' ');
    if (parts.length >= 2) return parts[0][0] + parts[1][0];
    return name.isNotEmpty ? name[0] : '?';
  }

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundImage: NetworkImage(imageUrl!),
      );
    }
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: AppColors.primary.withOpacity(0.1),
      child: Text(
        _getInitials().toUpperCase(),
        style: TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.bold,
          fontSize: size / 2.5,
        ),
      ),
    );
  }
}
