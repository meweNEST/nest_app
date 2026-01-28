import 'package:flutter/material.dart';

class NestPrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final Color backgroundColor;
  final Color hoverColor;
  final Color textColor;

  const NestPrimaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.backgroundColor = const Color(0xFFFF5757),
    this.hoverColor = const Color(0xFFFFBD59),
    this.textColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,         // FULL width of parent
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: 48,
          maxWidth: 400,
        ),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ButtonStyle(
            elevation: WidgetStateProperty.all(0),
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.hovered)) return hoverColor;
              return backgroundColor;
            }),
            padding: WidgetStateProperty.all(
              const EdgeInsets.symmetric(vertical: 14),
            ),
            textStyle: WidgetStateProperty.all(const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              fontFamily: 'Montserrat',
            )),
            shape: WidgetStateProperty.all(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          child: Text(text, style: TextStyle(color: textColor)),
        ),
      ),
    );
  }
}
