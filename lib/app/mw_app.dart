import 'package:flutter/material.dart';
import 'package:moonwell_launcher/app/login_screen/login_screen.dart';
import 'package:moonwell_launcher/app/theme/mw_theme.dart';

class MoonWellApp extends StatelessWidget {
  const MoonWellApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MoonWell',
      home: const LoginScreen(),
      theme: moonWellTheme(),
    );
  }
}
