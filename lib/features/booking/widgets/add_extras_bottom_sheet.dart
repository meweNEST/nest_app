import 'package:flutter/material.dart';

/// A modal bottom sheet for displaying booking summary and confirming the booking.
class AddExtrasBottomSheet extends StatefulWidget {
  final String workspaceName;
  final String workspaceSubline;
  final List<String> workspaceBenefits;

  const AddExtrasBottomSheet({
    super.key,
    required this.workspaceName,
    required this.workspaceSubline,
    required this.workspaceBenefits,
  });

  @override
  State<AddExtrasBottomSheet> createState() => _AddExtrasBottomSheetState();
}

class _AddExtrasBottomSheetState extends State<AddExtrasBottomSheet> {
  // --- STATE VARIABLES ---
  bool _isBringingChild = false; // NEU: State für die Child-Checkbox

  // --- COLORS ---
  static const Color nestDarkText = Color(0xFF333333);
  static const Color nestSecondaryText = Colors.grey;
  static const Color nestGreen = Color.fromRGBO(178, 229, 209, 1);
  static const Color nestRed = Color.fromRGBO(229, 62, 62, 1);
  static const Color membershipBannerBackground = Color.fromRGBO(178, 229, 209, 1);

  @override
  Widget build(BuildContext context) {
    const String displayDate = 'Tuesday, January 13, 2026';
    const String displayTime = '9:00 AM - 5:00 PM';
    final List<String> allWorkspaceBenefits = [...widget.workspaceBenefits, 'Childcare (inclusive) 👶'];

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(24.0), topRight: Radius.circular(24.0)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(24.0), topRight: Radius.circular(24.0)),
        child: Column(
          children: [
            // Top banner
            Container(
              decoration: const BoxDecoration(
                color: membershipBannerBackground,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(24.0), topRight: Radius.circular(24.0)),
              ),
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 18, color: nestDarkText),
                  SizedBox(width: 8),
                  Text('Included in your membership', style: TextStyle(fontWeight: FontWeight.bold, color: nestDarkText)),
                ],
              ),
            ),
            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('BOOKING DETAILS', style: TextStyle(color: nestDarkText, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.1)),
                    const SizedBox(height: 16),
                    const Text('Workspace', style: TextStyle(color: nestSecondaryText)),
                    Text(widget.workspaceName, style: const TextStyle(color: nestDarkText, fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    const Text('What this workspace offers', style: TextStyle(color: nestSecondaryText)),
                    const SizedBox(height: 8),
                    ...allWorkspaceBenefits.map((benefit) => _buildOfferTile(benefit, nestDarkText)).toList(),
                    const SizedBox(height: 16),
                    const Text('Date', style: TextStyle(color: nestSecondaryText)),
                    const Text(displayDate, style: TextStyle(color: nestDarkText, fontSize: 16)),
                    const SizedBox(height: 16),
                    const Text('Time', style: TextStyle(color: nestSecondaryText)),
                    const Text(displayTime, style: TextStyle(color: nestDarkText, fontSize: 16)),
                    const SizedBox(height: 24),

                    const Divider(),
                    const SizedBox(height: 16),

                    // NEU: "Bringing a child" Checkbox
                    _buildBringingChildCheckbox(),
                    const SizedBox(height: 24),

                    // Action Buttons
                    _buildActionButtons(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper für "What this workspace offers"
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

  // NEU: Widget für die Child-Checkbox
  Widget _buildBringingChildCheckbox() {
    return Row(
      children: [
        Checkbox(
          value: _isBringingChild,
          onChanged: (bool? value) {
            setState(() {
              _isBringingChild = value ?? false;
            });
          },
          activeColor: nestGreen,
          checkColor: Colors.white,
          side: const BorderSide(color: nestSecondaryText),
        ),
        const Text(
          "I'm bringing a child",
          style: TextStyle(color: nestDarkText, fontSize: 16),
        ),
      ],
    );
  }

  // Baut die Action Buttons
  Widget _buildActionButtons(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // CANCEL Button
        Expanded(
          child: SizedBox(
            height: 50,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: nestRed),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
              ),
              child: const Text('CANCEL', style: TextStyle(color: nestRed, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // CONFIRM BOOKING Button
        Expanded(
          child: SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: () async {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Checking availability and confirming...')));
                await Future.delayed(const Duration(seconds: 2));

                if (!mounted) return;

                final bool isAvailable = DateTime.now().minute % 5 != 0;

                if (isAvailable) {
                  // Bei Erfolg: Schließe das BottomSheet und gib 'true' zurück
                  Navigator.of(context).pop(true);
                } else {
                  // Bei Fehlschlag: Zeige Dialog und schließe danach ALLES
                  showDialog(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('Not Available'),
                      content: const Text('Sorry, the workspace is no longer available.'),
                      actions: [
                        TextButton(
                          child: const Text('OK'),
                          onPressed: () {
                            Navigator.of(dialogContext).pop(); // Schließt AlertDialog
                            Navigator.of(context).pop(false); // Schließt BottomSheet
                          },
                        ),
                      ],
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: nestGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
              ),
              child: const Text('CONFIRM BOOKING', style: TextStyle(color: nestDarkText, fontWeight: FontWeight.bold, fontSize: 14), textAlign: TextAlign.center),
            ),
          ),
        ),
      ],
    );
  }
}
