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

  static const Color _nestGreen = Color.fromRGBO(178, 229, 209, 1);
  static const Color _nestGreenDark = Color(0xFF1B8F5A); // darker green outline highlight
  static const Color _nestGreenDarker = Color(0xFF0E6B41); // selected + eligible emphasis
  static const Color _nestRed = Color.fromRGBO(229, 62, 62, 1);

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      // Make it fit without scrolling by keeping a reasonable max height,
      // and tightening internal spacing a bit.
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.62,
      ),
      padding: EdgeInsets.fromLTRB(24, 20, 24, 18 + bottomInset),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Meeting Room Booking',
              style: TextStyle(
                fontFamily: 'SweetAndSalty',
                fontSize: 26, // slightly smaller to avoid scroll
                color: AppTheme.darkText,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'How would you like to book this room?',
              style: TextStyle(
                fontFamily: 'CharlevoixPro',
                fontSize: 16,
                color: AppTheme.secondaryText,
              ),
            ),
            const SizedBox(height: 16),

            _buildSelectionTile(
              title: 'Book Entire Room (Private)',
              subtitle: 'Your own room for deep focus — no distractions, no sharing.',
              icon: _canBookPrivately ? Icons.lock_open_rounded : Icons.lock_outline,
              value: MeetingBookingType.private,
              isEnabled: _canBookPrivately,
              disabledReason: 'Only available for Premium Members',
              showExclusiveBadge: _canBookPrivately,
              emphasize: _canBookPrivately,
            ),
            const SizedBox(height: 12),
            _buildSelectionTile(
              title: 'Book a Single Seat (Shared)',
              subtitle: 'Share the room with other members.',
              icon: Icons.person_outline,
              value: MeetingBookingType.shared,
              isEnabled: true,
            ),

            const SizedBox(height: 16),

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
    bool showExclusiveBadge = false,
    bool emphasize = false,
  }) {
    final bool isSelected = _selectedOption == value;

    // Base colors
    final Color tileColor = isEnabled ? const Color.fromRGBO(235, 245, 241, 1) : Colors.grey[200]!;
    final Color textColor = isEnabled ? AppTheme.darkText : Colors.grey[500]!;
    final Color subTextColor = isEnabled ? AppTheme.secondaryText : Colors.grey[600]!;

    // Border logic:
    // - If eligible for private booking: darker green outline (even if not selected)
    // - If selected AND eligible: even darker green outline
    // - Otherwise: selected uses light green like before
    final Color borderColor = emphasize
        ? (isSelected ? _nestGreenDarker : _nestGreenDark)
        : (isSelected ? _nestGreen : Colors.black.withOpacity(0.06));

    final double borderWidth = (isSelected || emphasize) ? 2.0 : 1.0;

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
            color: borderColor,
            width: borderWidth,
          ),
          boxShadow: emphasize
              ? [
            BoxShadow(
              blurRadius: 10,
              offset: const Offset(0, 4),
              color: _nestGreenDark.withOpacity(0.10),
            )
          ]
              : null,
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
                if (showExclusiveBadge) ...[
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _nestGreenDark.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: _nestGreenDark.withOpacity(0.45)),
                    ),
                    child: const Text(
                      'EXCLUSIVE',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: _nestGreenDark,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Text(
              isEnabled ? subtitle : (disabledReason ?? ''),
              style: TextStyle(
                fontFamily: 'CharlevoixPro',
                fontSize: 14,
                color: subTextColor,
                height: 1.30,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtonsRow() {
    final bool canContinue = _selectedOption != null;

    return Column(
      children: [
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 50,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _nestRed),
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
                      color: _nestRed,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
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
                      backgroundColor: _nestGreen,
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
