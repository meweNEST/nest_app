// VOLLSTÄNDIG ERSETZEN: lib/features/auth/login_screen.dart

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  bool _agreeToTerms = false;
  bool _isLoading = false;
  bool _shouldShowTerms = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _shouldShowTerms = !(prefs.getBool('hasAcceptedTerms') ?? false);
    });
  }

  Future<void> _handleLogin() async {
    if (_isLoading || !mounted) return;
    final isFormValid = _shouldShowTerms ? _agreeToTerms : true;
    if (!isFormValid) {
      _showSnackbar('Please agree to the Terms & Conditions.', isError: true);
      return;
    }
    setState(() => _isLoading = true);

    print("--- VERSUCHE LOGIN für: ${_emailController.text} ---");

    try {
      final response = await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (response.session != null) {
        // --- DIESE ZEILE IST JETZT KORRIGIERT ---
        print("--- LOGIN ERFOLGREICH! User-ID: ${response.session!.user.id} ---");
        print("--- Auth-Stream sollte jetzt reagieren. Warte auf Navigation... ---");
      }

      if (mounted && _shouldShowTerms) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('hasAcceptedTerms', true);
      }
    } on AuthException catch (error) {
      print("--- AUTH-FEHLER: ${error.message} ---");
      if (mounted) _showSnackbar(error.message, isError: true);
    } catch (error) {
      print("--- UNBEKANNTER FEHLER: $error ---");
      if (mounted) _showSnackbar('An unexpected error occurred.', isError: true);
    }

    if (mounted) setState(() => _isLoading = false);
  }

  // Der Rest der Datei bleibt gleich
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: isError ? Theme.of(context).colorScheme.error : Colors.green));
  }

  void _handleSignUp() {
    showDialog(context: context, builder: (context) => SignUpDialog(onResult: _showSnackbar));
  }

  void _handleForgotPassword() {
    showDialog(context: context, builder: (context) => ForgotPasswordDialog(onResult: _showSnackbar));
  }

  static const Color buttonColor = Color(0xFF87A981);
  static const Color primaryTextColor = Color(0xFF4A4A4A);
  static const Color secondaryTextColor = Color(0xFF8A8A8A);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 60),
                Image.asset('assets/images/nest_logo.png', height: 100),
                const SizedBox(height: 40),
                Column(children: [const Text('WELCOME TO NEST', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryTextColor)), const SizedBox(height: 8), const Text('Your collaborative workspace', style: TextStyle(fontSize: 16, color: secondaryTextColor))]),
                const SizedBox(height: 32),
                TextField(controller: _emailController, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: 'Email', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                const SizedBox(height: 16),
                TextField(controller: _passwordController, obscureText: !_isPasswordVisible, decoration: InputDecoration(labelText: 'Password', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), suffixIcon: IconButton(icon: Icon(_isPasswordVisible ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible)))),
                if (_shouldShowTerms) const SizedBox(height: 16),
                if (_shouldShowTerms) Row(children: [Checkbox(value: _agreeToTerms, onChanged: (value) => setState(() => _agreeToTerms = value ?? false)), Expanded(child: RichText(text: TextSpan(style: TextStyle(fontSize: 14, color: secondaryTextColor), children: [const TextSpan(text: 'I agree to the '), TextSpan(text: 'Terms & Conditions', style: const TextStyle(decoration: TextDecoration.underline), recognizer: TapGestureRecognizer()..onTap = () {}), const TextSpan(text: ' and '), TextSpan(text: 'Privacy Policy', style: const TextStyle(decoration: TextDecoration.underline), recognizer: TapGestureRecognizer()..onTap = () {})])))]) ,
                const SizedBox(height: 24),
                ElevatedButton(onPressed: _isLoading ? null : _handleLogin, style: ElevatedButton.styleFrom(backgroundColor: buttonColor, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: _isLoading ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)) : const Text('LOG IN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white))),
                const SizedBox(height: 24),
                Column(children: [RichText(text: TextSpan(style: TextStyle(fontSize: 14, color: secondaryTextColor), children: [const TextSpan(text: "Don't have an account? "), TextSpan(text: 'Sign Up', style: const TextStyle(fontWeight: FontWeight.bold, color: buttonColor), recognizer: TapGestureRecognizer()..onTap = _handleSignUp)])), const SizedBox(height: 16), GestureDetector(onTap: _handleForgotPassword, child: const Text('Forgot Password?', style: TextStyle(fontSize: 14, color: secondaryTextColor, decoration: TextDecoration.underline)))]),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Dialog-Widgets...
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
      await supabase.auth.signUp(email: _emailController.text.trim(), password: _passwordController.text.trim());
      if (mounted) {
        Navigator.of(context).pop();
        widget.onResult('Success! Please check your email to confirm your account.', isError: false);
      }
    } on AuthException catch (error) {
      if (mounted) {
        Navigator.of(context).pop();
        widget.onResult(error.message, isError: true);
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Account'),
      content: Form(key: _formKey, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email'), keyboardType: TextInputType.emailAddress, validator: (v) => (v == null || !v.contains('@')) ? 'Please enter a valid email' : null),
        const SizedBox(height: 8),
        TextFormField(controller: _passwordController, decoration: const InputDecoration(labelText: 'Password'), obscureText: true, validator: (v) => (v == null || v.length < 6) ? 'Password must be at least 6 characters' : null),
        const SizedBox(height: 8),
        TextFormField(controller: _confirmPasswordController, decoration: const InputDecoration(labelText: 'Confirm Password'), obscureText: true, validator: (v) => v != _passwordController.text ? 'Passwords do not match' : null),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(onPressed: _isLoading ? null : _performSignUp, child: _isLoading ? const CircularProgressIndicator() : const Text('Sign Up')),
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
        Navigator.of(context).pop();
        widget.onResult('Success! A password reset link has been sent.', isError: false);
      }
    } on AuthException catch (error) {
      if (mounted) {
        Navigator.of(context).pop();
        widget.onResult(error.message, isError: true);
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reset Password'),
      content: Form(key: _formKey, child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Enter your email to receive a password reset link.'),
        const SizedBox(height: 16),
        TextFormField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email'), keyboardType: TextInputType.emailAddress, validator: (v) => (v == null || !v.contains('@')) ? 'Please enter a valid email' : null),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(onPressed: _isLoading ? null : _sendResetLink, child: _isLoading ? const CircularProgressIndicator() : const Text('Send Link')),
      ],
    );
  }
}
