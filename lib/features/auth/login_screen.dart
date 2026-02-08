import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nest_app/core/theme/app_theme.dart';
import 'package:nest_app/widgets/nest_button.dart';

import 'package:nest_app/features/main/main_screen.dart';

final supabase = Supabase.instance.client;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isLoading = false;

  static const Color _guestLinkColor = Color(0xFFB2E5D1);

  Future<void> _upsertUserRow(User user) async {
    // ✅ FIX: your users.email is NOT NULL -> always include it
    final email = user.email;
    if (email == null || email.trim().isEmpty) {
      // Extremely unlikely for email/password, but prevents null insert attempts.
      return;
    }

    await supabase.from('users').upsert(
      {
        'id': user.id,
        'email': email.trim(),
      },
      onConflict: 'id',
    );
  }

  Future<void> _handleLogin() async {
    if (_isLoading || !mounted) return;
    setState(() => _isLoading = true);

    try {
      final res = await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final user = res.user;
      if (user != null) {
        // Create/ensure users row exists
        try {
          await _upsertUserRow(user);
        } catch (e) {
          // Don’t scare the user; login worked.
          // ignore: avoid_print
          print('User row upsert failed: $e');
        }
      }

      if (!mounted) return;

      // ✅ Always go into the app after a successful login
      if (res.session != null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainScreen()),
        );
      }
    } on AuthException catch (e) {
      _showSnackbar(e.message, isError: true);
    } catch (e) {
      _showSnackbar("Login failed: $e", isError: true);
    }

    if (mounted) setState(() => _isLoading = false);
  }

  void _showSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? Theme.of(context).colorScheme.error : Colors.green,
      ),
    );
  }

  void _handleSignUp() {
    showDialog(
      context: context,
      builder: (_) => SignUpDialog(onResult: _showSnackbar),
    );
  }

  void _handleForgotPassword() {
    showDialog(
      context: context,
      builder: (_) => ForgotPasswordDialog(onResult: _showSnackbar),
    );
  }

  Future<void> _handleContinueAsGuest() async {
    if (!mounted) return;

    final go = await showDialog<bool>(
          context: context,
          barrierDismissible: true,
          builder: (ctx) => Dialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Continue as guest?',
                    style: TextStyle(
                      fontFamily: 'SweetAndSalty',
                      fontSize: 22,
                      color: AppTheme.darkText,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'You can explore the app as a guest.\n\nBooking will require logging in.',
                    style: TextStyle(
                      fontFamily: 'CharlevoixPro',
                      fontSize: 14,
                      color: AppTheme.secondaryText,
                      height: 1.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(50)),
                            side: BorderSide(
                                color: Colors.black.withValues(alpha: 0.18)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text(
                            'Back',
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontWeight: FontWeight.w600,
                              color: AppTheme.darkText,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: NestPrimaryButton(
                          text: 'Continue',
                          backgroundColor: const Color(0xFFB2E5D1),
                          textColor: Colors.white,
                          onPressed: () => Navigator.of(ctx).pop(true),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ) ??
        false;

    if (!go || !mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainScreen()),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const SizedBox(height: 60),
              Image.asset('assets/images/nest_logo.png', height: 95),
              const SizedBox(height: 32),
              const Text(
                'WELCOME TO NEST',
                style: TextStyle(
                  fontFamily: 'SweetAndSalty',
                  fontSize: 32,
                  color: AppTheme.darkText,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Your collaborative workspace',
                style: TextStyle(
                  fontFamily: 'CharlevoixPro',
                  fontSize: 16,
                  color: AppTheme.secondaryText,
                ),
              ),
              const SizedBox(height: 40),
              _buildFloatingInput(controller: _emailController, label: "Email"),
              const SizedBox(height: 16),
              _buildFloatingInput(
                controller: _passwordController,
                label: "Password",
                obscure: !_isPasswordVisible,
                suffix: IconButton(
                  icon: Icon(
                    _isPasswordVisible
                        ? Icons.visibility_off
                        : Icons.visibility,
                    color: Colors.grey,
                  ),
                  onPressed: () =>
                      setState(() => _isPasswordVisible = !_isPasswordVisible),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: _handleForgotPassword,
                  child: const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text(
                      "Forgot Password?",
                      style: TextStyle(
                        decoration: TextDecoration.underline,
                        fontFamily: 'CharlevoixPro',
                        color: AppTheme.darkText,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: SizedBox(
                  width: 200,
                  child: NestPrimaryButton(
                    text: _isLoading ? "LOADING..." : "LOG IN",
                    backgroundColor: const Color(0xFFB2E5D1),
                    textColor: Colors.white,
                    onPressed: () {
                      if (_isLoading) return;
                      _handleLogin();
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _buildSignupText(),
              const SizedBox(height: 10),
              RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontFamily: 'CharlevoixPro',
                    fontSize: 14,
                    color: AppTheme.secondaryText,
                  ),
                  children: [
                    TextSpan(
                      text: 'Continue as guest',
                      style: const TextStyle(
                        fontFamily: 'CharlevoixPro',
                        fontWeight: FontWeight.bold,
                        color: _guestLinkColor,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = _handleContinueAsGuest,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingInput({
    required TextEditingController controller,
    required String label,
    bool obscure = false,
    Widget? suffix,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        style: const TextStyle(
          fontFamily: 'CharlevoixPro',
          fontSize: 16,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
            fontFamily: 'CharlevoixPro',
            fontSize: 16,
            color: Colors.grey,
          ),
          floatingLabelStyle: const TextStyle(
            fontFamily: 'CharlevoixPro',
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppTheme.darkText,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          suffixIcon: suffix,
        ),
      ),
    );
  }

  Widget _buildSignupText() {
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontFamily: 'CharlevoixPro',
          fontSize: 14,
          color: AppTheme.secondaryText,
        ),
        children: [
          const TextSpan(text: "Don't have an account? "),
          TextSpan(
            text: 'Sign Up',
            style: const TextStyle(
              fontFamily: 'CharlevoixPro',
              fontWeight: FontWeight.bold,
              color: AppTheme.bookingButtonColor,
            ),
            recognizer: TapGestureRecognizer()..onTap = _handleSignUp,
          ),
        ],
      ),
    );
  }
}

// --- dialogs below (only change: upsert includes email too) ---

class SignUpDialog extends StatefulWidget {
  final Function(String message, {bool isError}) onResult;
  const SignUpDialog({super.key, required this.onResult});

  @override
  State<SignUpDialog> createState() => _SignUpDialogState();
}

class _SignUpDialogState extends State<SignUpDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _upsertUserRow(User user) async {
    final email = user.email;
    if (email == null || email.trim().isEmpty) return;

    await supabase.from('users').upsert(
      {'id': user.id, 'email': email.trim()},
      onConflict: 'id',
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _performSignUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final res = await supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (res.user != null) {
        try {
          await _upsertUserRow(res.user!);
        } catch (e) {
          // ignore: avoid_print
          print('User row upsert failed after signup: $e');
        }
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onResult(
          'Success! If email confirmation is enabled, please check your inbox.',
          isError: false,
        );
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      widget.onResult(e.message, isError: true);
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      widget.onResult("Sign up failed: $e", isError: true);
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Account'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: (v) =>
                  v != null && v.contains('@') ? null : 'Enter a valid email',
            ),
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
              validator: (v) =>
                  v != null && v.length >= 6 ? null : 'Min. 6 characters',
            ),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirm Password'),
              validator: (v) => v == _passwordController.text
                  ? null
                  : 'Passwords do not match',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _isLoading ? null : _performSignUp,
          child: _isLoading
              ? const CircularProgressIndicator()
              : const Text('Sign Up'),
        ),
      ],
    );
  }
}

class ForgotPasswordDialog extends StatefulWidget {
  final Function(String message, {bool isError}) onResult;
  const ForgotPasswordDialog({super.key, required this.onResult});

  @override
  State<ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<ForgotPasswordDialog> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetLink() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await supabase.auth.resetPasswordForEmail(_emailController.text.trim());

      if (mounted) {
        Navigator.pop(context);
        widget.onResult('Success! A password reset link has been sent.',
            isError: false);
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      widget.onResult(e.message, isError: true);
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      widget.onResult("An unexpected error occurred: $e", isError: true);
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reset Password'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter your email to receive a reset link.'),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: (v) =>
                  v != null && v.contains('@') ? null : 'Enter a valid email',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _isLoading ? null : _sendResetLink,
          child: _isLoading
              ? const CircularProgressIndicator()
              : const Text('Send Link'),
        ),
      ],
    );
  }
}
