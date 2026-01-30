// lib/features/auth/login_screen.dart

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nest_app/core/theme/app_theme.dart';
import 'package:nest_app/widgets/nest_button.dart';

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
    _shouldShowTerms = !(prefs.getBool('hasAcceptedTerms') ?? false);
    if (mounted) setState(() {});
  }

  Future<void> _handleLogin() async {
    if (_isLoading || !mounted) return;

    final isValid = _shouldShowTerms ? _agreeToTerms : true;

    if (!isValid) {
      _showSnackbar("Please agree to the Terms & Conditions.", isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (response.session != null && _shouldShowTerms) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('hasAcceptedTerms', true);
      }
    } on AuthException catch (e) {
      _showSnackbar(e.message, isError: true);
    } catch (_) {
      _showSnackbar("An unexpected error occurred.", isError: true);
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

              Image.asset(
                'assets/images/nest_logo.png',
                height: 95,
              ),

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

              _buildFloatingInput(
                controller: _emailController,
                label: "Email",
              ),

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

              const SizedBox(height: 16),

              if (_shouldShowTerms) _buildTnC(),

              const SizedBox(height: 24),

              Center(
                child: SizedBox(
                  width: 200,   // << MATCHES MEMBERSHIP BUTTON EXACTLY
                  child: NestPrimaryButton(
                    text: "LOG IN",
                    backgroundColor: const Color(0xFFB2E5D1),
                    textColor: Colors.white,
                    onPressed: () {
                      if (_isLoading) return;
                      _handleLogin();
                    },
                  ),
                ),
              ),

              const SizedBox(height: 24),

              _buildSignupText(),

              const SizedBox(height: 16),

              GestureDetector(
                onTap: _handleForgotPassword,
                child: const Text(
                  "Forgot Password?",
                  style: TextStyle(
                    decoration: TextDecoration.underline,
                    fontFamily: 'CharlevoixPro',
                    color: AppTheme.darkText,
                  ),
                ),
              ),

              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }

  /// FLOATING INPUT FIELD
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
            color: Colors.black.withOpacity(0.06),
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

  /// TERMS
  Widget _buildTnC() {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: _agreeToTerms,
            onChanged: (value) =>
                setState(() => _agreeToTerms = value ?? false),
          ),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontFamily: 'CharlevoixPro',
                  fontSize: 14,
                  color: AppTheme.secondaryText,
                  height: 1.4,
                ),
                children: [
                  const TextSpan(text: "I agree to the "),
                  TextSpan(
                    text: "Terms & Conditions",
                    style: const TextStyle(
                      decoration: TextDecoration.underline,
                      color: AppTheme.darkText,
                      fontWeight: FontWeight.bold,
                    ),
                    recognizer: TapGestureRecognizer()..onTap = () {},
                  ),
                  const TextSpan(text: " and "),
                  TextSpan(
                    text: "Privacy Policy",
                    style: const TextStyle(
                      decoration: TextDecoration.underline,
                      color: AppTheme.darkText,
                      fontWeight: FontWeight.bold,
                    ),
                    recognizer: TapGestureRecognizer()..onTap = () {},
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// SIGNUP TEXT
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

//
// -----------------------------------------------------
// SIGN UP DIALOG (restored)
// -----------------------------------------------------
//

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
      await supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onResult(
          'Success! Please check your email to confirm your account.',
          isError: false,
        );
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      widget.onResult(e.message, isError: true);
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
              validator: (v) =>
              v == _passwordController.text ? null : 'Passwords do not match',
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
          child:
          _isLoading ? const CircularProgressIndicator() : const Text('Sign Up'),
        ),
      ],
    );
  }
}

//
// -----------------------------------------------------
// FORGOT PASSWORD DIALOG (restored)
// -----------------------------------------------------
//

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
      await supabase.auth.resetPasswordForEmail(
        _emailController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onResult(
          'Success! A password reset link has been sent.',
          isError: false,
        );
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      widget.onResult(e.message, isError: true);
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
