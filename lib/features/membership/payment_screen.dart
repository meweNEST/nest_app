// lib/features/membership/payment_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For PlatformException
import 'package:flutter_stripe/flutter_stripe.dart'; // Correct Stripe imports
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nest_app/features/membership/stripe_service.dart'; // Your custom Stripe service

class PaymentScreen extends StatefulWidget {
  final int membershipId;
  final String membershipName;
  final String
      membershipPrice; // This comes as 'X,XX' from MembershipScreen (e.g., "2,95")
  final Color membershipColor;
  final String promoCode;
  final bool isSubscription; // true for recurring, false for one-time

  const PaymentScreen({
    super.key,
    required this.membershipId,
    required this.membershipName,
    required this.membershipPrice,
    required this.membershipColor,
    this.promoCode = '',
    this.isSubscription = true, // Defaulting to true for memberships
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();

  bool _isProcessing = false;
  bool _acceptedTerms = false;
  String?
      _discountAmountDisplay; // How much discount to display (e.g., "10% off" or "€5.00 off")
  double _finalAmount = 0.0; // The final amount after promo code, in EUR

  // CardFormEditController is essential for CardFormField
  late CardFormEditController _cardController; // Initialized in initState

  // Color constants (keeping these static const as they are compile-time constants)
  static const Color coral = Color(0xFFFF6B6B);
  static const Color grayText = Color(0xFF9E9E9E);
  static const Color creamBackground = Color(0xFFFDF8F3);
  static const Color darkText = Color(0xFF2D2D2D);
  static const Color successGreen = Color(0xFF4CAF50);
  static const Color errorRed = Color(0xFFE53E3E);

  @override
  void initState() {
    super.initState();
    _cardController = CardFormEditController(); // Initialize here

    // Parse the membershipPrice string (e.g., '2,95')
    // Replace comma with dot for proper double parsing
    _finalAmount = double.parse(widget.membershipPrice.replaceAll(',', '.'));

    // Validate promo code if provided (this is frontend display logic for now)
    // The actual discount application will happen in your Supabase Edge Function
    if (widget.promoCode.isNotEmpty) {
      _validatePromoCodeForDisplay();
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _cardController.dispose(); // Dispose the card controller
    super.dispose();
  }

  // Frontend-only promo code validation for display purposes.
  // The actual discount calculation and application for payment happens in your Edge Function.
  Future<void> _validatePromoCodeForDisplay() async {
    try {
      // Query your 'promo_codes' table to get discount details for display
      final response = await Supabase.instance.client
          .from('promo_codes')
          .select('discount_amount, discount_type')
          .eq('code',
              widget.promoCode.toUpperCase()) // Assuming codes are uppercase
          .eq('is_active', true)
          .maybeSingle(); // Use maybeSingle to handle no results gracefully

      if (response != null) {
        final discountAmount = response['discount_amount'] as num;
        final discountType = response['discount_type'] as String;

        setState(() {
          double tempFinalAmount =
              double.parse(widget.membershipPrice.replaceAll(',', '.'));
          if (discountType == 'percentage') {
            final discount = tempFinalAmount * (discountAmount / 100);
            tempFinalAmount = tempFinalAmount - discount;
            _discountAmountDisplay = '${discountAmount.toInt()}% off';
          } else {
            // 'fixed_amount'
            tempFinalAmount = tempFinalAmount - discountAmount.toDouble();
            _discountAmountDisplay =
                '€${discountAmount.toStringAsFixed(2)} off';
          }
          // Ensure price doesn't go below zero
          _finalAmount = tempFinalAmount > 0 ? tempFinalAmount : 0.0;
        });
      } else {
        // Promo code not found or invalid in DB, reset display and show info
        setState(() {
          _discountAmountDisplay = null;
          _finalAmount = double.parse(widget.membershipPrice
              .replaceAll(',', '.')); // Reset to original price
        });
        if (mounted) {
          _showSnackBar(
              'Promo code "${widget.promoCode}" is invalid or expired.',
              isError: false);
        }
      }
    } catch (e) {
      debugPrint('Error validating promo code for display: $e');
      setState(() {
        _discountAmountDisplay = null;
        _finalAmount = double.parse(widget.membershipPrice
            .replaceAll(',', '.')); // Reset to original price
      });
      if (mounted) {
        _showSnackBar('Error checking promo code.', isError: true);
      }
    }
  }

  Future<void> _processPayment() async {
    if (!_formKey.currentState!.validate()) {
      _showSnackBar('Please fill all required fields.', isError: true);
      return;
    }
    if (!_acceptedTerms) {
      _showSnackBar('Please accept the Terms of Service.', isError: true);
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // 1. Call your Supabase Edge Function via StripeService to get clientSecret
      // This is secure because your secret key is ONLY on Supabase's server.
      final paymentIntentResponse = await StripeService.createPaymentIntent(
        widget.membershipId,
        widget.promoCode.isEmpty ? null : widget.promoCode,
      );

      if (paymentIntentResponse == null ||
          !paymentIntentResponse.containsKey('clientSecret')) {
        throw Exception(
            'Failed to get clientSecret from backend. Check Edge Function logs.');
      }

      final clientSecret = paymentIntentResponse['clientSecret'];
      final String? stripeCustomerId = paymentIntentResponse['customerId']
          as String?; // Optional from backend

      // 2. Confirm the payment with Stripe using the clientSecret
      final paymentIntent = await Stripe.instance.confirmPayment(
        paymentIntentClientSecret: clientSecret,
        data: PaymentMethodParams.card(
          // Use 'data' parameter for v12.2.0
          paymentMethodData: PaymentMethodData(
            billingDetails: BillingDetails(
              email: _emailController.text,
              name: _nameController.text,
            ),
          ),
        ),
      );

      // Handle payment confirmation result
      if (paymentIntent.status == PaymentIntentsStatus.Succeeded) {
        // Payment succeeded, now save the record in your database
        await _savePaymentToDatabase(paymentIntent, stripeCustomerId);
        _showSuccessDialog();
      } else if (paymentIntent.status == PaymentIntentsStatus.Canceled ||
          // Using specific known "failed" states for flutter_stripe v12.2.0
          paymentIntent.status == PaymentIntentsStatus.RequiresPaymentMethod ||
          paymentIntent.status == PaymentIntentsStatus.RequiresAction) {
        _showSnackBar(
            // REVISED: Remove direct access to lastPaymentError, use a generic message for these statuses.
            'Payment ${paymentIntent.status.name}: An error occurred during payment confirmation. Please try again.',
            isError: true);
      } else {
        _showSnackBar(
            'Payment process completed with status: ${paymentIntent.status.name}.',
            isError: false);
      }
    } on StripeException catch (e) {
      // Handle Stripe-specific errors
      _showSnackBar(
          'Payment failed: ${e.error.message ?? "Unknown Stripe error"}',
          isError: true);
      debugPrint('Stripe Error: ${e.error.message}');
    } on PlatformException catch (e) {
      // Handle platform-specific exceptions (e.g., user cancelled Apple Pay)
      _showSnackBar('Payment cancelled or failed: ${e.message}',
          isError: false);
      debugPrint('Platform Exception: ${e.message}');
    } catch (e) {
      // Catch any other unexpected errors
      debugPrint('Unexpected payment error: $e');
      _showSnackBar('An unexpected error occurred during payment: $e',
          isError: true);
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  // Saves the completed payment details to your Supabase 'payments' table
  Future<void> _savePaymentToDatabase(
      PaymentIntent paymentIntent, String? stripeCustomerId) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        debugPrint('Error: User not logged in, cannot save payment.');
        _showSnackBar('User not logged in. Cannot save payment record.',
            isError: true);
        return;
      }

      // Convert amount from Stripe (cents) to EUR
      final double amountInEur = paymentIntent.amount / 100.0;

      await Supabase.instance.client.from('payments').insert({
        'user_id': userId,
        'membership_id': widget.membershipId,
        'stripe_payment_intent_id': paymentIntent.id,
        'stripe_customer_id': stripeCustomerId,
        // Use the customer ID from backend if available
        'amount': amountInEur,
        'currency': paymentIntent.currency,
        'status': paymentIntent.status.name,
        // Use .name for enum
        'promo_code': widget.promoCode.isEmpty ? null : widget.promoCode,
        'created_at': DateTime.now().toIso8601String(),
        // metadata was removed as it was causing issues and might not be directly available/needed for insert
      });
      debugPrint('Payment saved to database successfully!');
    } catch (e) {
      debugPrint('Error saving payment to database: $e');
      _showSnackBar('Error saving payment record to database: $e',
          isError: true);
    }
  }

  // Displays a snackbar message
  void _showSnackBar(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message), // SnackBar content now uses Text widget
        backgroundColor: isError ? errorRed : Colors.blueAccent,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // Shows a success dialog after successful payment
  void _showSuccessDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle,
              color: successGreen,
              size: 80,
            ),
            const SizedBox(height: 20),
            const Text(
              'Payment Successful!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: darkText,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Welcome to ${widget.membershipName}!',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: grayText,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // Navigate back to home or a confirmation screen
                  Navigator.of(context).pop(); // Close dialog
                  Navigator.of(context).pop(); // Go back to MembershipScreen
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: successGreen,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                child: const Text(
                  'Continue',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Format the price for display. _finalAmount is already a double, format it to two decimal places
    final displayedPrice = _finalAmount.toStringAsFixed(2).replaceAll('.', ',');

    return Scaffold(
      backgroundColor: creamBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: darkText),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Complete Your Membership',
          style: TextStyle(
            color: darkText,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            // This Column is explicitly the single child of Form
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Membership Summary Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: widget.membershipColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: widget.membershipColor.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.membershipName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: darkText,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (widget.promoCode.isNotEmpty &&
                        _discountAmountDisplay != null) ...[
                      // Original Price (strike-through)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Original Price:',
                            style: TextStyle(
                              fontSize: 16,
                              color: grayText,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          Text(
                            '€${widget.membershipPrice}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: grayText,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Promo and Final Price
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: successGreen.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                  color: successGreen.withOpacity(0.3)),
                            ),
                            child: Text(
                              '${widget.promoCode} ($_discountAmountDisplay)',
                              style: const TextStyle(
                                color: successGreen,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const Text(
                            'Final Price:',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: darkText,
                            ),
                          ),
                          Text(
                            '€$displayedPrice',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: successGreen,
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      // Only show total due if no promo or promo failed
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Due:',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: darkText,
                            ),
                          ),
                          Text(
                            '€$displayedPrice',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: widget.membershipColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // Customer Information
              const Text(
                'Your Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: darkText,
                ),
              ),
              const SizedBox(height: 15),

              // Email Field
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  prefixIcon: const Icon(Icons.email),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  // Using a basic email check that avoids complex string literal issues.
                  if (!value.contains('@') || !value.contains('.')) {
                    return 'Please enter a valid email address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 15),

              // Name Field
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your full name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 30),

              // Payment Information
              const Text(
                'Payment Details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: darkText,
                ),
              ),
              const SizedBox(height: 15),

              // Stripe Card Form
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: CardFormField(
                  controller: _cardController, // Use the initialized controller
                  style: CardFormStyle(
                    textColor: darkText,
                    fontSize: 16,
                    placeholderColor: grayText,
                  ),
                  // onCardChanged: (card) {
                  //   // Optional: You can react to card changes here
                  // },
                ),
              ),
              const SizedBox(height: 20),

              // Terms and Conditions
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _acceptedTerms,
                    onChanged: (value) {
                      setState(() {
                        _acceptedTerms = value ?? false;
                      });
                    },
                    activeColor: widget.membershipColor,
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _acceptedTerms = !_acceptedTerms;
                        });
                      },
                      child: const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text(
                          'I agree to the Terms of Service and Privacy Policy',
                          style: TextStyle(
                            color: grayText,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),

              // Pay Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed:
                      _isProcessing || !_acceptedTerms ? null : _processPayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.membershipColor,
                    disabledBackgroundColor: grayText,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isProcessing
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Processing...',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          'Pay €$displayedPrice',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),

              // Security Notice
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.blue.shade200,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.security,
                      color: Colors.blue.shade600,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Your payment is secured by Stripe. We never store your card details.',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
