import 'package:flutter/material.dart';

/// A modal bottom sheet for the final booking confirmation/payment step.
class FinalBookingConfirmationSheet extends StatelessWidget {
  final String workspaceName;
  final String workspaceSubline;
  final List<String> workspaceBenefits;

  const FinalBookingConfirmationSheet({
    super.key,
    required this.workspaceName,
    required this.workspaceSubline,
    required this.workspaceBenefits,
  });

  // --- COLORS (für Konsistenz, könnte auch aus AppTheme kommen) ---
  static const Color nestDarkText = Color(0xFF333333);
  static const Color nestSecondaryText = Colors.grey;
  static const Color nestGreen = Color.fromRGBO(178, 229, 209, 1);
  static const Color nestRed = Color.fromRGBO(229, 62, 62, 1);
  static const Color membershipBannerBackground =
      Color.fromRGBO(178, 229, 209, 1); // Hellgrün

  @override
  Widget build(BuildContext context) {
    // Statische Platzhalter für Datum und Zeit
    const String displayDate = 'Tuesday, January 13, 2026';
    const String displayTime = '9:00 AM - 5:00 PM';

    final List<String> allWorkspaceBenefits = [
      ...workspaceBenefits,
      'Childcare (inclusive) 👶',
    ];

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24.0),
          topRight: Radius.circular(24.0),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24.0),
          topRight: Radius.circular(24.0),
        ),
        child: Column(
          children: [
            // Top banner: "Included in your membership"
            Container(
              decoration: const BoxDecoration(
                color: membershipBannerBackground, // Grüne Farbe
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24.0),
                  topRight: Radius.circular(24.0),
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 18, color: nestDarkText),
                  SizedBox(width: 8),
                  Text(
                    'Included in your membership',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: nestDarkText),
                  ),
                ],
              ),
            ),
            // Scrollable main content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'FINAL BOOKING', // Angepasster Titel
                      style: TextStyle(
                        color: nestDarkText,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Workspace',
                        style: TextStyle(color: nestSecondaryText)),
                    Text(
                      workspaceName,
                      style: const TextStyle(
                        color: nestDarkText,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('What this workspace offers',
                        style: TextStyle(color: nestSecondaryText)),
                    const SizedBox(height: 8),
                    ...allWorkspaceBenefits.map(
                        (benefit) => _buildOfferTile(benefit, nestDarkText)),
                    const SizedBox(height: 16),
                    const Text('Date',
                        style: TextStyle(color: nestSecondaryText)),
                    Text(displayDate,
                        style:
                            const TextStyle(color: nestDarkText, fontSize: 16)),
                    const SizedBox(height: 16),
                    const Text('Time',
                        style: TextStyle(color: nestSecondaryText)),
                    Text(displayTime,
                        style:
                            const TextStyle(color: nestDarkText, fontSize: 16)),
                    const SizedBox(height: 8),
                    const Text(
                      'Included in your membership',
                      style: TextStyle(
                          color: nestGreen,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24),

                    // Hier würden zukünftige Payment- oder zusätzliche Bestätigungselemente hinkommen
                    // Zum Beispiel: Textfelder für Kreditkartendaten, "Confirm Payment" Button, etc.
                    const Text(
                      'Payment Details',
                      style: TextStyle(
                        color: nestDarkText,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                        'Your membership covers this booking. No additional payment required.',
                        style: TextStyle(color: nestSecondaryText)),
                    const SizedBox(height: 24),

                    _buildFinalActionButtons(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper for "What this workspace offers" items
  Widget _buildOfferTile(String text, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Icon(Icons.check, color: textColor, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(color: textColor))),
        ],
      ),
    );
  }

  Widget _buildFinalActionButtons(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        SizedBox(
          width: 180,
          height: 50,
          child: ElevatedButton(
            onPressed: () {
              // Simuliere den Abschluss der Buchung
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('Finalizing booking for $workspaceName...')),
              );
              // Hier würde die eigentliche Buchung an Supabase gesendet werden
              Navigator.of(context)
                  .pop(); // Schließt den FinalBookingConfirmationSheet
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: nestGreen,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25)),
              padding: EdgeInsets.zero,
            ),
            child: const Text(
              'CONFIRM BOOKING',
              style: TextStyle(
                  color: nestDarkText,
                  fontWeight: FontWeight.bold,
                  fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 180,
          height: 50,
          child: OutlinedButton(
            onPressed: () {
              Navigator.of(context)
                  .pop(); // Schließt den FinalBookingConfirmationSheet
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: nestRed),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25)),
              padding: EdgeInsets.zero,
            ),
            child: const Text(
              'CANCEL',
              style: TextStyle(
                  color: nestRed, fontWeight: FontWeight.bold, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}
