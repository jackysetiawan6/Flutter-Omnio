import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/app_theme.dart';
import 'pages/home_screen.dart';

class OmnioApp extends StatefulWidget {
  const OmnioApp({super.key});

  @override
  State<OmnioApp> createState() => _OmnioAppState();
}

class _OmnioAppState extends State<OmnioApp> {
  ThemeMode _themeMode = ThemeMode.system;
  bool _ready = false;
  bool _showSplash = true;
  bool _loggedIn = false;
  String _displayName = 'Omnio member';
  late SharedPreferences _preferences;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    _preferences = await SharedPreferences.getInstance();
    final storedTheme = _preferences.getString('theme_mode');
    if (storedTheme == 'light') _themeMode = ThemeMode.light;
    if (storedTheme == 'dark') _themeMode = ThemeMode.dark;
    _loggedIn = _preferences.getBool('logged_in') ?? false;
    _displayName = _preferences.getString('display_name') ?? 'Omnio member';
    if (!mounted) return;
    setState(() => _ready = true);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (mounted) setState(() => _showSplash = false);
  }

  Future<void> _toggleTheme() async {
    final next = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    setState(() => _themeMode = next);
    await _preferences.setString('theme_mode', next == ThemeMode.light ? 'light' : 'dark');
  }

  Future<void> _login(String name) async {
    final safeName = name.trim().isEmpty ? 'Omnio member' : name.trim();
    await _preferences.setBool('logged_in', true);
    await _preferences.setString('display_name', safeName);
    if (mounted) setState(() { _loggedIn = true; _displayName = safeName; });
  }

  Future<void> _logout() async {
    await _preferences.setBool('logged_in', false);
    if (mounted) setState(() => _loggedIn = false);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Omnio',
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: _themeMode,
        home: !_ready || _showSplash
            ? const _SplashScreen()
            : _loggedIn
                ? OmnioScreen(onToggleTheme: _toggleTheme, onLogout: _logout, displayName: _displayName)
                : _AuthPage(onLoggedIn: _login),
      );
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            ClipRRect(borderRadius: BorderRadius.circular(28), child: Image.asset('assets/omnio_icon.png', width: 86, height: 86)),
            const SizedBox(height: 20),
            Text('omnio', style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -1)),
            const SizedBox(height: 8),
            Text('Life, neatly together.', style: Theme.of(context).textTheme.bodyLarge),
          ]),
        ),
      );
}

class _AuthPage extends StatefulWidget {
  const _AuthPage({required this.onLoggedIn});
  final ValueChanged<String> onLoggedIn;

  @override
  State<_AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<_AuthPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _register = false;
  bool _obscure = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_emailController.text.trim().isEmpty || _passwordController.text.isEmpty || (_register && _nameController.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please complete the fields to continue.')));
      return;
    }
    widget.onLoggedIn(_register ? _nameController.text : _emailController.text.split('@').first);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.bolt_rounded, color: Theme.of(context).colorScheme.primary, size: 42),
                  const SizedBox(height: 24),
                  Text(_register ? 'Create your Omnio' : 'Welcome back', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(_register ? 'One calm place for the things that matter.' : 'Sign in to pick up where you left off.'),
                  const SizedBox(height: 28),
                  if (_register) ...[TextField(controller: _nameController, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'Your name', prefixIcon: Icon(Icons.person_outline))), const SizedBox(height: 12)],
                  TextField(controller: _emailController, keyboardType: TextInputType.emailAddress, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'Email address', prefixIcon: Icon(Icons.alternate_email))),
                  const SizedBox(height: 12),
                  TextField(controller: _passwordController, obscureText: _obscure, onSubmitted: (_) => _submit(), decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(onPressed: () => setState(() => _obscure = !_obscure), icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined)))),
                  const SizedBox(height: 20),
                  SizedBox(width: double.infinity, child: FilledButton(onPressed: _submit, child: Text(_register ? 'Create account' : 'Sign in'))),
                  const SizedBox(height: 12),
                  Center(child: TextButton(onPressed: () => setState(() => _register = !_register), child: Text(_register ? 'Already have an account? Sign in' : 'New here? Create an account'))),
                  const SizedBox(height: 12),
                  Center(child: Text('Demo mode: any valid-looking details will work.', style: Theme.of(context).textTheme.bodySmall)),
                ]),
              ),
            ),
          ),
        ),
      );
}
