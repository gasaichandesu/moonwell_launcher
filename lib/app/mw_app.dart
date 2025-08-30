import 'package:flutter/material.dart';
import 'package:moonwell_launcher/app/home_screen/home_screen.dart';
import 'package:moonwell_launcher/app/theme/mw_theme.dart';

class MoonWellApp extends StatelessWidget {
  const MoonWellApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MoonWell',
      home: const HomeScreen(),
      theme: moonWellTheme(),
    );
  }
}
