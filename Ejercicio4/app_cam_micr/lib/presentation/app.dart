import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import 'providers/settings_provider.dart';
import 'screens/home_shell.dart';

class CamMicApp extends StatelessWidget {
  const CamMicApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return MaterialApp(
      title: 'CamMic ESCOM',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(settings.palette),
      darkTheme: AppTheme.dark(settings.palette),
      themeMode: settings.themeMode, // ThemeMode.system → sigue al sistema
      home: const HomeShell(),
    );
  }
}
