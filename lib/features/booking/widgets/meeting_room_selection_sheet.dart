// lib/features/booking/widgets/meeting_room_selection_sheet.dart

import 'package:flutter/material.dart';
import 'package:nest_app/core/theme/app_theme.dart';
import 'package:nest_app/widgets/nest_button.dart';
import '../models/booking_models.dart';

/// A modal bottom sheet to allow users to select how they want to book a meeting room.
class MeetingRoomSelectionSheet extends StatefulWidget {
  final UserMembership currentUserMembership;

  const MeetingRoomSelectionSheet({
    super.key,
    required this.currentUserMembership,
  });

  @override
  State<MeetingRoomSelectionSheet> createState() => _MeetingRoomSelectionSheetState();
}

class _MeetingRoomSelectionSheetState extends State<MeetingRoomSelectionSheet> {
  MeetingBookingType? _selectedOption;

  // 'full' does not exist in our enum; premium is the highest tier.
  bool get _canBookPrivately => widget.currentUserMembership == UserMembership.premium;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      // Avoid fixed height overflow; allow the sheet to size naturally with a max height.
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.70,
      ),
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24.0),
          topRight: Radius.circular(24.0),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Meeting Room Booking',
              style: TextStyle(
                fontFamily: 'SweetAndSalty',
                fontSize: 28,
                color: AppTheme.darkText,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'How would you like to book this room?',
              style: TextStyle(
                fontFamily: 'CharlevoixPro',
                fontSize: 16,
                color: AppTheme.secondaryText,
              ),
            ),
            const SizedBox(height: 24),

            // Scrollable content so buttons never overflow
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildSelectionTile(
                      title: 'Book Entire Room (Private)',
                      subtitle: 'For you and your guests.',
                      icon: Icons.lock_outline,
                      value: MeetingBookingType.private,
                      isEnabled: _canBookPrivately,
                      disabledReason: 'Only available for Premium Members',
                    ),
                    const SizedBox(height: 16),
                    _buildSelectionTile(
                      title: 'Book a Single Seat (Shared)',
                      subtitle: 'Share the room with other members.',
                      icon: Icons.person_outline,
                      value: MeetingBookingType.shared,
                      isEnabled: true,
                    ),

                    // Extra breathing room before the buttons (as requested)
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),

            // Buttons side-by-side
            _buildActionButtonsRow(),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required MeetingBookingType value,
    required bool isEnabled,
    String? disabledReason,
  }) {
    final bool isSelected = _selectedOption == value;

    final Color tileColor = isEnabled ? const Color.fromRGBO(235, 245, 241, 1) : Colors.grey[200]!;
    final Color textColor = isEnabled ? AppTheme.darkText : Colors.grey[500]!;
    final Color subTextColor = isEnabled ? AppTheme.secondaryText : Colors.grey[600]!;

    return GestureDetector(
      onTap: isEnabled
          ? () {
        setState(() {
          _selectedOption = value;
        });
      }
          : null,
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: tileColor,
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(
            color: isSelected ? const Color.fromRGBO(178, 229, 209, 1) : Colors.black.withOpacity(0.06),
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: textColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'CharlevoixPro',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              isEnabled ? subtitle : (disabledReason ?? ''),
              style: TextStyle(
                fontFamily: 'CharlevoixPro',
                fontSize: 14,
                color: subTextColor,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtonsRow() {
    const Color nestGreen = Color.fromRGBO(178, 229, 209, 1);
    const Color nestRed = Color.fromRGBO(229, 62, 62, 1);

    final bool canContinue = _selectedOption != null;

    return Column(
      children: [
        const SizedBox(height: 8), // a bit more space above buttons

        Row(
          children: [
            // Cancel (outline-style but same rounded shape + font)
            Expanded(
              child: SizedBox(
                height: 50,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: nestRed),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      fontFamily: 'CharlevoixPro',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: nestRed,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Continue (NestPrimaryButton style)
            Expanded(
              child: SizedBox(
                height: 50,
                child: Opacity(
                  opacity: canContinue ? 1.0 : 0.45,
                  child: IgnorePointer(
                    ignoring: !canContinue,
                    child: NestPrimaryButton(
                      text: 'CONTINUE',
                      onPressed: () => Navigator.of(context).pop(_selectedOption),
                      backgroundColor: nestGreen,
                      textColor: const Color(0xFF333333),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
