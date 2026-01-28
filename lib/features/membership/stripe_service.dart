// lib/features/membership/stripe_service.dart
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart'; // For debugPrint

class StripeService {
  // This function is now solely responsible for calling your Supabase Edge Function
  // to create a Payment Intent and retrieve the client_secret.
  // The actual Stripe API call with your STRIPE_SECRET_KEY happens securely on your Supabase backend.
  static Future<Map<String, dynamic>?> createPaymentIntent(
      int membershipId, String? promoCode) async {
    try {
      final supabase = Supabase.instance.client;

      // Your Edge Function 'create-payment-intent' already handles the secure
      // interaction with Stripe using your STRIPE_SECRET_KEY.
      final response = await supabase.functions.invoke(
        'create-payment-intent', // The name of your deployed Supabase Edge Function
        body: jsonEncode({
          'membership_id': membershipId,
          // Pass the promo code to your Edge Function if it needs to adjust the price
          'promo_code': promoCode,
        }),
      );

      if (response.status == 200 && response.data != null) {
        debugPrint('Edge Function Response: ${response.data}');
        return response.data as Map<String, dynamic>;
      } else {
        throw Exception(
            'Failed to invoke Edge Function: ${response.status} - ${response.data}');
      }
    } catch (e) {
      debugPrint('Error in StripeService.createPaymentIntent: $e');
      // Re-throw to be caught by the calling function for user feedback
      rethrow;
    }
  }

  // The createCustomer and createSubscription methods are placeholders
  // for if you needed to perform these operations directly from Flutter.
  // Currently, your PaymentScreen only needs to call createPaymentIntent.
  // These should ideally also be handled by secure backend functions.
  static Future<String?> createCustomer({
    required String email,
    required String name,
  }) async {
    debugPrint('StripeService.createCustomer is a placeholder. '
        'This operation should ideally be done via your backend (Supabase Edge Function or similar) '
        'to avoid exposing your secret key.');
    // Simulate backend call (you would replace this with a call to your own secure backend endpoint)
    await Future.delayed(const Duration(milliseconds: 500));
    // Return a dummy customer ID for now, as it's not used in current flow
    return 'cus_dummy_customer_id';
  }

  static Future<Map<String, dynamic>?> createSubscription({
    required String customerId,
    required String priceId,
    String? promoCode,
    Map<String, String>? metadata,
  }) async {
    debugPrint('StripeService.createSubscription is a placeholder. '
        'This operation should ideally be done via your backend (Supabase Edge Function or similar) '
        'to avoid exposing your secret key.');
    // Simulate backend call (you would replace this with a call to your own secure backend endpoint)
    await Future.delayed(const Duration(milliseconds: 500));
    return {
      'id': 'sub_dummy_id',
      'status': 'active',
      'latest_invoice': {
        'payment_intent': {
          'client_secret': 'pi_dummy_client_secret_xyz',
        },
      },
      'current_period_start': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'current_period_end': DateTime.now().add(const Duration(days: 30)).millisecondsSinceEpoch ~/ 1000,
    };
  }
}
