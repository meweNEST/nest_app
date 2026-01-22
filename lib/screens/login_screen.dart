// --- START DES FINALEN, KORRIGIERTEN UND VOLLSTÄNDIGEN CODES ---

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Helper to access Supabase client
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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_isLoading || !mounted) return;
    if (!_agreeToTerms) {
      _showSnackbar('Please agree to the Terms & Conditions and Privacy Policy.', isError: true);
      return;
    }
    setState(() => _isLoading = true);

    try {
      final authResponse = await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (authResponse.user != null && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } on AuthException catch (error) {
      if (mounted) _showSnackbar(error.message, isError: true);
    } catch (error) {
      if (mounted) _showSnackbar('An unexpected error occurred.', isError: true);
    }

    if (mounted) setState(() => _isLoading = false);
  }

  void _showSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : Colors.green,
      ),
    );
  }

  void _handleSignUp() {
    showDialog(
      context: context,
      builder: (context) => SignUpDialog(
        // KORRIGIERTE ZEILE:
        onResult: _showSnackbar,
      ),
    );
  }

  void _handleForgotPassword() {
    showDialog(
      context: context,
      builder: (context) => ForgotPasswordDialog(
        // KORRIGIERTE ZEILE:
        onResult: _showSnackbar,
      ),
    );
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
                _buildLogo(),
                const SizedBox(height: 40),
                _buildWelcomeText(),
                const SizedBox(height: 32),
                _buildEmailField(),
                const SizedBox(height: 16),
                _buildPasswordField(),
                const SizedBox(height: 16),
                _buildTermsCheckbox(),
                const SizedBox(height: 24),
                _buildLoginButton(),
                const SizedBox(height: 24),
                _buildFooter(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() => Image.asset('assets/nest_logo.png', height: 100, errorBuilder: (c, o, s) => const SizedBox(height: 100));
  Widget _buildWelcomeText() => Column(children: [const Text('WELCOME TO NEST', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryTextColor)), const SizedBox(height: 8), const Text('Your collaborative workspace', style: TextStyle(fontSize: 16, color: secondaryTextColor))]);
  Widget _buildEmailField() => TextField(controller: _emailController, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: 'Email', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))));
  Widget _buildPasswordField() => TextField(controller: _passwordController, obscureText: !_isPasswordVisible, decoration: InputDecoration(labelText: 'Password', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), suffixIcon: IconButton(icon: Icon(_isPasswordVisible ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible))));
  Widget _buildTermsCheckbox() => Row(children: [Checkbox(value: _agreeToTerms, onChanged: (value) => setState(() => _agreeToTerms = value ?? false)), Expanded(child: RichText(text: TextSpan(style: TextStyle(fontSize: 14, color: secondaryTextColor, fontFamily: Theme.of(context).textTheme.bodyLarge?.fontFamily), children: [const TextSpan(text: 'I agree to the '), TextSpan(text: 'Terms & Conditions', style: const TextStyle(decoration: TextDecoration.underline), recognizer: TapGestureRecognizer()..onTap = () {}), const TextSpan(text: ' and '), TextSpan(text: 'Privacy Policy', style: const TextStyle(decoration: TextDecoration.underline), recognizer: TapGestureRecognizer()..onTap = () {})])))]);
  Widget _buildLoginButton() => ElevatedButton(onPressed: _handleLogin, style: ElevatedButton.styleFrom(backgroundColor: buttonColor, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: _isLoading ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)) : const Text('LOG IN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)));
  Widget _buildFooter() => Column(children: [RichText(text: TextSpan(style: TextStyle(fontSize: 14, color: secondaryTextColor, fontFamily: Theme.of(context).textTheme.bodyLarge?.fontFamily), children: [const TextSpan(text: "Don't have an account? "), TextSpan(text: 'Sign Up', style: const TextStyle(fontWeight: FontWeight.bold, color: buttonColor), recognizer: TapGestureRecognizer()..onTap = _handleSignUp)])), const SizedBox(height: 16), GestureDetector(onTap: _handleForgotPassword, child: const Text('Forgot Password?', style: TextStyle(fontSize: 14, color: secondaryTextColor, decoration: TextDecoration.underline)))]);
}

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
    if (!_formKey.currentState!.validate() || !mounted) return;
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
        ElevatedButton(onPressed: _isLoading ? null : _performSignUp, child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 3)) : const Text('Sign Up')),
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
    if (!_formKey.currentState!.validate() || !mounted) return;
    setState(() => _isLoading = true);

    try {
      await supabase.auth.resetPasswordForEmail(_emailController.text.trim());
      if (mounted) {
        Navigator.of(context).pop();
        widget.onResult('Success! If an account exists, a password reset link has been sent.', isError: false);
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
        const Text('Enter your email and we will send you a link to reset your password.'),
        const SizedBox(height: 16),
        TextFormField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email'), keyboardType: TextInputType.emailAddress, validator: (v) => (v == null || !v.contains('@')) ? 'Please enter a valid email' : null),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(onPressed: _isLoading ? null : _sendResetLink, child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 3)) : const Text('Send Link')),
      ],
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('NEST Home'), actions: [
        IconButton(icon: const Icon(Icons.logout), onPressed: () async {
          await supabase.auth.signOut();
          if (context.mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
        })
      ]),
      body: const Center(child: Text('Welcome to NEST!\n\nYou are successfully logged in.', textAlign: TextAlign.center, style: TextStyle(fontSize: 24))),
    );
  }
}

// --- ENDE DES FINALEN, KORRIGIERTEN UND VOLLSTÄNDIGEN CODES ---
