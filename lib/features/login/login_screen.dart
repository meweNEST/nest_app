import 'package:flutter/material.dart';
import 'package:nest_app/core/theme/app_theme.dart';
import 'package:nest_app/widgets/nest_button.dart';
import '../main/main_screen.dart';

const Text(
'HELLO THIS IS NEW LOGIN UI',

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // CONTROLLERS
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // STATE
  bool _obscurePassword = true;
  bool _acceptedTerms = false;
  bool _showConsentError = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // NAVIGATION CALLBACKS
  void _login() {
    if (!_acceptedTerms) {
      setState(() => _showConsentError = true);
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainScreen()),
    );
  }

  void _goToSignup() {
    // TODO: add your sign‑up navigation
  }

  void _goToForgotPassword() {
    // TODO: add your forgot password navigation
  }

  void _openTerms() {
    // TODO: open terms link
  }

  void _openPrivacy() {
    // TODO: open privacy link
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [

              const SizedBox(height: 40),

              // LOGO
              Image.asset(
                'assets/images/nest_logo.png',
                height: 95,
              ),

              const SizedBox(height: 24),

              // HEADLINE
              const Text(
                'WELCOME TO NEST',
                style: TextStyle(
                  fontFamily: 'SweetAndSalty',
                  fontSize: 30,
                  color: AppTheme.darkText,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 4),

              // SUBLINE
              const Text(
                'Your collaborative workspace',
                style: TextStyle(
                  fontFamily: 'CharlevoixPro',
                  fontSize: 16,
                  color: AppTheme.secondaryText,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 40),

              // EMAIL FIELD
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _emailController,
                  style: const TextStyle(
                    fontFamily: 'CharlevoixPro',
                    fontSize: 16,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Email',
                    hintStyle: TextStyle(
                      fontFamily: 'CharlevoixPro',
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // PASSWORD FIELD
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: const TextStyle(
                    fontFamily: 'CharlevoixPro',
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Password',
                    hintStyle: const TextStyle(
                      fontFamily: 'CharlevoixPro',
                      color: Colors.grey,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: Colors.grey,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // TERMS CHECKBOX
              Row(
                children: [
                  Checkbox(
                    value: _acceptedTerms,
                    onChanged: (value) =>
                        setState(() => _acceptedTerms = value ?? false),
                  ),
                  Expanded(
                    child: Wrap(
                      children: [
                        const Text(
                          'I agree to the ',
                          style: TextStyle(
                            fontFamily: 'CharlevoixPro',
                            fontSize: 14,
                          ),
                        ),
                        GestureDetector(
                          onTap: _openTerms,
                          child: const Text(
                            'Terms & Conditions',
                            style: TextStyle(
                              fontFamily: 'CharlevoixPro',
                              fontWeight: FontWeight.bold,
                              color: AppTheme.darkText,
                            ),
                          ),
                        ),
                        const Text(
                          ' and ',
                          style: TextStyle(fontFamily: 'CharlevoixPro'),
                        ),
                        GestureDetector(
                          onTap: _openPrivacy,
                          child: const Text(
                            'Privacy Policy',
                            style: TextStyle(
                              fontFamily: 'CharlevoixPro',
                              fontWeight: FontWeight.bold,
                              color: AppTheme.darkText,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              if (_showConsentError)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    'Please accept the terms to continue.',
                    style: TextStyle(
                      fontFamily: 'CharlevoixPro',
                      color: Colors.red,
                      fontSize: 13,
                    ),
                  ),
                ),

              const SizedBox(height: 20),

              // LOGIN BUTTON
              SizedBox(
                width: double.infinity,
                child: NestPrimaryButton(
                  text: 'LOG IN',
                  onPressed: _login,
                  backgroundColor: AppTheme.sageGreen,
                ),
              ),

              const SizedBox(height: 20),

              // SIGN UP
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Don't have an account? ",
                    style: TextStyle(
                      fontFamily: 'CharlevoixPro',
                      color: AppTheme.secondaryText,
                    ),
                  ),
                  GestureDetector(
                    onTap: _goToSignup,
                    child: const Text(
                      'Sign Up',
                      style: TextStyle(
                        fontFamily: 'CharlevoixPro',
                        color: AppTheme.bookingButtonColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // RESET PASSWORD
              GestureDetector(
                onTap: _goToForgotPassword,
                child: const Text(
                  'Forgot Password?',
                  style: TextStyle(
                    fontFamily: 'CharlevoixPro',
                    color: AppTheme.darkText,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
