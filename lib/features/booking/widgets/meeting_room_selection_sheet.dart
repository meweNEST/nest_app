// VOLLSTÄNDIG ERSETZEN: lib/features/booking/widgets/meeting_room_selection_sheet.dart

import 'package:flutter/material.dart';
import '../models/booking_models.dart'; // WICHTIG: Der neue, zentrale Import

/// A modal bottom sheet to allow users to select how they want to book a meeting room.
class MeetingRoomSelectionSheet extends StatefulWidget {
  final UserMembership currentUserMembership;

  const MeetingRoomSelectionSheet({
    super.key,
    required this.currentUserMembership,
  });

  @override
  State<MeetingRoomSelectionSheet> createState() =>
      _MeetingRoomSelectionSheetState();
}

class _MeetingRoomSelectionSheetState extends State<MeetingRoomSelectionSheet> {
  MeetingBookingType? _selectedOption;

  // HINWEIS: 'full' gibt es in unserem zentralen Enum nicht.
  // Wir nehmen stattdessen 'premium' als die höchste Stufe.
  bool get _canBookPrivately => widget.currentUserMembership == UserMembership.premium;

  @override
  Widget build(BuildContext context) {
    const Color nestDarkText = Color(0xFF333333);
    const Color nestSecondaryText = Colors.grey;
    const Color nestGreen = Color.fromRGBO(178, 229, 209, 1);
    const Color nestRed = Color.fromRGBO(229, 62, 62, 1);

    return Container(
      height: MediaQuery.of(context).size.height * 0.55,
      padding: const EdgeInsets.all(24.0),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24.0),
          topRight: Radius.circular(24.0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Meeting Room Booking',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: nestDarkText,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'How would you like to book this room?',
            style: TextStyle(fontSize: 16, color: nestSecondaryText),
          ),
          const SizedBox(height: 24),

          // Option 1: Book entire room
          _buildSelectionTile(
            title: 'Book Entire Room (Private)',
            subtitle: 'For you and your guests.',
            icon: Icons.lock_outline,
            value: MeetingBookingType.private,
            isEnabled: _canBookPrivately,
            disabledReason: 'Only available for Premium Members',
          ),
          const SizedBox(height: 16),

          // Option 2: Book a single seat
          _buildSelectionTile(
            title: 'Book a Single Seat (Shared)',
            subtitle: 'Share the room with other members.',
            icon: Icons.person_outline,
            value: MeetingBookingType.shared, // 'sharedSeat' umbenannt zu 'shared'
            isEnabled: true, // Always enabled
          ),
          const Spacer(),

          _buildActionButtons(),
        ],
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
    const Color nestLightGreenBackground = Color.fromRGBO(235, 245, 241, 1);
    final Color tileColor = isEnabled ? nestLightGreenBackground : Colors.grey[200]!;
    final Color textColor = isEnabled ? Colors.black87 : Colors.grey[500]!;

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
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(
            color: isSelected ? const Color.fromRGBO(178, 229, 209, 1) : Colors.transparent,
            width: 2.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: textColor),
                const SizedBox(width: 12),
                Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
              ],
            ),
            const SizedBox(height: 4),
            Text(isEnabled ? subtitle : disabledReason!, style: TextStyle(color: isEnabled ? Colors.black54 : Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    const Color nestRed = Color.fromRGBO(229, 62, 62, 1);
    return Column(
      children: [
        SizedBox(
          width: 250,
          height: 50,
          child: ElevatedButton(
            onPressed: _selectedOption != null ? () => Navigator.of(context).pop(_selectedOption) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromRGBO(178, 229, 209, 1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
              disabledBackgroundColor: Colors.grey[300],
            ),
            child: const Text('CONTINUE', style: TextStyle(color: Color(0xFF333333), fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: 250,
          height: 50,
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              side: const BorderSide(color: nestRed),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
            ),
            child: const Text('Cancel', style: TextStyle(color: nestRed)),
          ),
        ),
      ],
    );
  }
}
