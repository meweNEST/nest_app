import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Standardized error handling for the NEST app.
/// Use this instead of manual try-catch blocks to ensure consistent user feedback.
class ErrorHandler {
  /// Shows an error message to the user via SnackBar.
  /// Logs the error details for debugging.
  ///
  /// Usage:
  /// ```dart
  /// try {
  ///   await someOperation();
  /// } catch (e) {
  ///   ErrorHandler.showError(context, e, userMessage: 'Failed to save profile');
  /// }
  /// ```
  static void showError(
    BuildContext context,
    Object error, {
    String? userMessage,
    Duration duration = const Duration(seconds: 4),
  }) {
    // Log the full error for debugging
    debugPrint('❌ Error: $error');
    if (error is Error) {
      debugPrint('Stack trace: ${error.stackTrace}');
    }

    // Determine user-friendly message
    final String message = _getUserFriendlyMessage(error, userMessage);

    // Show snackbar to user
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red.shade700,
          duration: duration,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ),
      );
    }
  }

  /// Shows a success message to the user via SnackBar.
  ///
  /// Usage:
  /// ```dart
  /// await saveProfile();
  /// ErrorHandler.showSuccess(context, 'Profile saved successfully');
  /// ```
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green.shade700,
          duration: duration,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Shows a warning message to the user via SnackBar.
  static void showWarning(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.orange.shade700,
          duration: duration,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Converts technical errors into user-friendly messages.
  static String _getUserFriendlyMessage(Object error, String? customMessage) {
    // Use custom message if provided
    if (customMessage != null && customMessage.isNotEmpty) {
      return customMessage;
    }

    // Handle specific error types
    if (error is AuthException) {
      return _handleAuthException(error);
    }

    if (error is PostgrestException) {
      return _handleDatabaseException(error);
    }

    // Network/timeout errors
    if (error.toString().contains('SocketException') ||
        error.toString().contains('TimeoutException') ||
        error.toString().contains('HandshakeException')) {
      return 'No internet connection. Please check your network.';
    }

    // Format conversion errors
    if (error is FormatException) {
      return 'Invalid data format. Please try again.';
    }

    // Generic fallback
    return 'Something went wrong. Please try again.';
  }

  /// Handles Supabase auth errors with specific messages.
  static String _handleAuthException(AuthException error) {
    switch (error.statusCode) {
      case '400':
        if (error.message.contains('Invalid login credentials')) {
          return 'Wrong email or password. Please try again.';
        }
        return 'Invalid request. Please check your input.';
      case '401':
        return 'Your session has expired. Please log in again.';
      case '422':
        if (error.message.contains('email')) {
          return 'This email is already registered.';
        }
        return 'Invalid email or password format.';
      case '429':
        return 'Too many attempts. Please wait a moment and try again.';
      default:
        return error.message.isNotEmpty
            ? error.message
            : 'Authentication failed. Please try again.';
    }
  }

  /// Handles Supabase database errors with specific messages.
  static String _handleDatabaseException(PostgrestException error) {
    final code = error.code;
    final message = error.message.toLowerCase();

    // Foreign key violations
    if (code == '23503' || message.contains('foreign key')) {
      return 'This item is linked to other data and cannot be deleted.';
    }

    // Unique constraint violations
    if (code == '23505' || message.contains('unique')) {
      return 'This already exists. Please use a different value.';
    }

    // Permission errors
    if (code == '42501' || message.contains('permission')) {
      return 'You don\'t have permission to do this.';
    }

    // Row level security
    if (message.contains('row-level security') || message.contains('policy')) {
      return 'Access denied. Please contact support.';
    }

    return 'Database error. Please try again later.';
  }

  /// Wraps an async operation with error handling.
  /// Shows loading indicator and handles errors automatically.
  ///
  /// Usage:
  /// ```dart
  /// await ErrorHandler.handle(
  ///   context: context,
  ///   operation: () async {
  ///     await saveProfile();
  ///   },
  ///   successMessage: 'Profile saved',
  ///   errorMessage: 'Failed to save profile',
  /// );
  /// ```
  static Future<T?> handle<T>({
    required BuildContext context,
    required Future<T> Function() operation,
    String? successMessage,
    String? errorMessage,
    bool showLoading = false,
  }) async {
    try {
      if (showLoading && context.mounted) {
        // Show loading indicator
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }

      final result = await operation();

      if (showLoading && context.mounted) {
        Navigator.of(context).pop(); // Close loading indicator
      }

      if (successMessage != null && context.mounted) {
        showSuccess(context, successMessage);
      }

      return result;
    } catch (e) {
      if (showLoading && context.mounted) {
        Navigator.of(context).pop(); // Close loading indicator
      }

      if (context.mounted) {
        showError(context, e, userMessage: errorMessage);
      }

      return null;
    }
  }
}
