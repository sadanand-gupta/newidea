import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../state/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/glass.dart';
import '../widgets/kx_background.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLogin = true;
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text.trim();
    final auth = context.read<AuthProvider>();

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    bool success;
    if (_isLogin) {
      success = await auth.login(username, password);
    } else {
      final email = _emailCtrl.text.trim();
      success = await auth.signup(username, password, email.isEmpty ? null : email);
    }

    if (!mounted) return;
    if (success) {
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error ?? 'Unknown error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return KxBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo/Title
                  Text('KryptoX', style: KxText.display(48).copyWith(letterSpacing: -2)),
                  const SizedBox(height: 8),
                  Text(
                    'Crypto Market Research',
                    style: KxText.body(14, color: KxColors.textDim),
                  ),
                  const SizedBox(height: 40),

                  // Login/Signup toggle
                  GlassCard(
                    radius: 12,
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        Expanded(
                          child: _TabButton(
                            label: 'Login',
                            active: _isLogin,
                            onTap: () => setState(() => _isLogin = true),
                          ),
                        ),
                        Expanded(
                          child: _TabButton(
                            label: 'Sign Up',
                            active: !_isLogin,
                            onTap: () => setState(() => _isLogin = false),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Username field
                  _TextField(
                    label: 'Username',
                    controller: _usernameCtrl,
                    hint: 'Enter your username',
                    icon: Icons.person_outline_rounded,
                  ),
                  const SizedBox(height: 12),

                  // Password field
                  _TextField(
                    label: 'Password',
                    controller: _passwordCtrl,
                    hint: 'Min 6 characters',
                    icon: Icons.lock_outline_rounded,
                    obscure: true,
                  ),
                  const SizedBox(height: 12),

                  // Email field (signup only)
                  if (!_isLogin) ...[
                    _TextField(
                      label: 'Email (optional)',
                      controller: _emailCtrl,
                      hint: 'your@email.com',
                      icon: Icons.mail_outline_rounded,
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Submit button
                  Consumer<AuthProvider>(
                    builder: (context, auth, _) => SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: auth.isLoading ? null : _submit,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: KxColors.brandGradient,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: auth.isLoading
                                ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                                )
                                : Text(
                                  _isLogin ? 'Login' : 'Sign Up',
                                  style: KxText.body(16, weight: FontWeight.w700, color: Colors.black),
                                ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Info text
                  Text(
                    _isLogin ? "Don't have an account? Sign up above" : 'Already have an account? Login above',
                    style: KxText.body(12, color: KxColors.textMuted),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          gradient: active ? KxColors.brandGradient : null,
          borderRadius: BorderRadius.circular(10),
          color: active ? null : Colors.transparent,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: KxText.body(14, weight: FontWeight.w600, color: active ? Colors.black : KxColors.textDim),
        ),
      ),
    );
  }
}

class _TextField extends StatefulWidget {
  const _TextField({
    required this.label,
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;

  @override
  State<_TextField> createState() => _TextFieldState();
}

class _TextFieldState extends State<_TextField> {
  late bool _showPassword;

  @override
  void initState() {
    super.initState();
    _showPassword = !widget.obscure;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: KxText.body(12, weight: FontWeight.w600, color: KxColors.textDim)),
        const SizedBox(height: 6),
        GlassCard(
          radius: 12,
          padding: EdgeInsets.zero,
          child: TextField(
            controller: widget.controller,
            obscureText: widget.obscure && !_showPassword,
            cursorColor: KxColors.cyan,
            style: KxText.body(15),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: widget.hint,
              hintStyle: KxText.body(15, color: KxColors.textMuted),
              prefixIcon: Icon(widget.icon, color: KxColors.textMuted),
              suffixIcon: widget.obscure
                  ? IconButton(
                    icon: Icon(
                      _showPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                      color: KxColors.textMuted,
                    ),
                    onPressed: () => setState(() => _showPassword = !_showPassword),
                  )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }
}
