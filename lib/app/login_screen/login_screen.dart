import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moonwell_launcher/app/home_screen/home_screen.dart';
import 'package:moonwell_launcher/app/theme/mw_theme.dart';
import 'package:moonwell_launcher/features/launcher/data/launcher_api_client.dart';
import 'package:moonwell_launcher/service_container.dart';
import 'package:window_manager/window_manager.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      setState(() => _error = 'Введите логин и пароль.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = getIt<LauncherApiClient>();
      final session = await api.login(username: username, password: password);
      final manifest = await api.fetchManifest(session.accessToken);

      if (!mounted) return;

      await Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) =>
              HomeScreen(session: session, manifest: manifest),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = _formatError(e);
      });
    }
  }

  String _formatError(Object error) {
    final raw = error.toString();
    if (raw.startsWith('Exception: ')) return raw.substring(11);
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: Image.asset('assets/background.png', fit: BoxFit.cover),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.0,
                  colors: [
                    MWColors.abyss.withAlpha(200),
                    MWColors.abyss.withAlpha(240),
                  ],
                ),
              ),
            ),
          ),
          // Title bar
          Positioned(top: 0, left: 0, right: 0, child: _TitleBar(cs: cs)),
          // Login form — centered
          Center(
            child: SizedBox(
              width: 340,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo
                  Image.asset(
                    'assets/logo.png',
                    height: 160,
                    filterQuality: FilterQuality.high,
                  ),
                  const SizedBox(height: 32),
                  // Card
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: MWColors.abyss.withAlpha(210),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: cs.outline.withAlpha(80)),
                      boxShadow: [
                        BoxShadow(
                          color: MWColors.primary.withAlpha(30),
                          blurRadius: 40,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _usernameController,
                          enabled: !_isLoading,
                          decoration: const InputDecoration(
                            labelText: 'Логин',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _passwordController,
                          enabled: !_isLoading,
                          obscureText: true,
                          onSubmitted: (_) => _login(),
                          decoration: const InputDecoration(
                            labelText: 'Пароль',
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                          textInputAction: TextInputAction.done,
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _login,
                            child: _isLoading
                                ? SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: cs.onPrimary,
                                    ),
                                  )
                                : const Text('Войти'),
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: cs.error, fontSize: 13),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TitleBar extends StatelessWidget {
  const _TitleBar({required this.cs});
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (_) => windowManager.startDragging(),
      child: SizedBox(
        height: 36,
        child: Row(
          children: [
            const Spacer(),
            _TitleBarButton(
              icon: Icons.remove,
              onTap: () => windowManager.minimize(),
              color: cs.onSurface,
            ),
            _TitleBarButton(
              icon: Icons.crop_square,
              onTap: () async {
                if (await windowManager.isMaximized()) {
                  await windowManager.unmaximize();
                } else {
                  await windowManager.maximize();
                }
              },
              color: cs.onSurface,
            ),
            _TitleBarButton(
              icon: Icons.close,
              onTap: () => SystemNavigator.pop(),
              color: MWColors.error,
            ),
          ],
        ),
      ),
    );
  }
}

class _TitleBarButton extends StatelessWidget {
  const _TitleBarButton({
    required this.icon,
    required this.onTap,
    required this.color,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: 40,
        height: 36,
        child: Icon(icon, size: 16, color: color.withAlpha(180)),
      ),
    );
  }
}
