import 'package:flutter/material.dart';
import '../../../../core/theme/app_tokens.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(leading: const Icon(Icons.person), title: const Text('Profile'), onTap: () {}),
          ListTile(leading: const Icon(Icons.lock), title: const Text('Security'), onTap: () {}),
          ListTile(leading: const Icon(Icons.palette), title: const Text('Appearance'), onTap: () {}),
          ListTile(leading: const Icon(Icons.notifications), title: const Text('Notifications'), onTap: () {}),
          ListTile(leading: const Icon(Icons.info), title: const Text('About'), onTap: () {}),
          ListTile(leading: Icon(Icons.logout, color: AppColors.error), title: Text('Logout', style: TextStyle(color: AppColors.error)), onTap: () {}),
        ],
      ),
    );
  }
}
