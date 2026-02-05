import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nest_app/core/theme/app_theme.dart';
import 'package:nest_app/widgets/nest_button.dart';

/// A modal bottom sheet for displaying booking summary and confirming the booking.
class AddExtrasBottomSheet extends StatefulWidget {
  final String workspaceName;
  final String workspaceSubline;
  final List<String> workspaceBenefits;

  /// ✅ NEW: The selected time range from the schedule screen (LOCAL time).
  final DateTime startLocal;
  final DateTime endLocal;

  const AddExtrasBottomSheet({
    super.key,
    required this.workspaceName,
    required this.workspaceSubline,
    required this.workspaceBenefits,
    required this.startLocal,
    required this.endLocal,
  });

  @override
  State<AddExtrasBottomSheet> createState() => _AddExtrasBottomSheetState();
}

class _AddExtrasBottomSheetState extends State<AddExtrasBottomSheet> {
  bool _isBringingChild = false;

  bool _isLoadingEligibility = true;
  bool _isEligible = false;

  // Colors (keep your palette)
  static const Color nestDarkText = Color(0xFF333333);
  static const Color nestSecondaryText = Colors.grey;
  static const Color nestGreen = Color.fromRGBO(178, 229, 209, 1);
  static const Color nestRed = Color.fromRGBO(229, 62, 62, 1);

  @override
  void initState() {
    super.initState();
    _loadEligibility();
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is String) return DateTime.tryParse(v); // date columns return 'YYYY-MM-DD'
    return null;
  }

  Future<void> _loadEligibility() async {
    setState(() => _isLoadingEligibility = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        if (!mounted) return;
        setState(() {
          _isEligible = false;
          _isLoadingEligibility = false;
        });
        return;
      }

      // public.users has RLS: auth.uid() = id (SELECT allowed).
      final row = await Supabase.instance.client
          .from('users')
          .select('id,email,membership_type,membership_status,membership_start_date,membership_end_date')
          .eq('id', user.id)
          .maybeSingle();

      bool eligible = false;

      if (row != null) {
        final membershipType = (row['membership_type'] ?? '').toString().trim();
        final membershipStatus = (row['membership_status'] ?? '').toString().trim().toLowerCase();

        final start = _parseDate(row['membership_start_date']);
        final end = _parseDate(row['membership_end_date']);

        final today = _dateOnly(DateTime.now());
        final startOk = start == null ? false : !_dateOnly(start).isAfter(today);
        final endOk = end == null ? true : !_dateOnly(end).isBefore(today);

        eligible = membershipType.isNotEmpty && membershipStatus == 'active' && startOk && endOk;
      }

      if (!mounted) return;
      setState(() {
        _isEligible = eligible;
        _isLoadingEligibility = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isEligible = false;
        _isLoadingEligibility = false;
      });
    }
  }

  void _goToMembership() {
    // Close sheet, then navigate
    final rootNav = Navigator.of(context, rootNavigator: true);
    Navigator.of(context).pop(false);
    rootNav.pushNamed('/membership');
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Use the chosen day/time from ScheduleScreen
    final localizations = MaterialLocalizations.of(context);
    final String displayDate = localizations.formatFullDate(widget.startLocal);
    final String displayTime =
        '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(widget.startLocal))} - '
        '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(widget.endLocal))}';

    final bool eligible = (!_isLoadingEligibility && _isEligible);

    final Color bannerBg = eligible ? nestGreen : const Color(0xFFFFECEC);
    final IconData bannerIcon = eligible ? Icons.check_circle_outline : Icons.cancel_outlined;
    final String bannerText = eligible ? 'Included in your membership' : 'Not included in your membership';

    final benefits = <String>[
      ...widget.workspaceBenefits,
      if (eligible) 'Childcare (inclusive) 👶',
    ];

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
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
            // Top banner
            Container(
              decoration: BoxDecoration(
                color: bannerBg,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24.0),
                  topRight: Radius.circular(24.0),
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 10.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(bannerIcon, size: 18, color: nestDarkText),
                  const SizedBox(width: 8),
                  Text(
                    _isLoadingEligibility ? 'Checking membership…' : bannerText,
                    style: const TextStyle(
                      fontFamily: 'CharlevoixPro',
                      fontWeight: FontWeight.bold,
                      color: nestDarkText,
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                // ✅ translucent content if not eligible
                child: Opacity(
                  opacity: eligible ? 1.0 : 0.55,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'BOOKING DETAILS',
                        style: TextStyle(
                          fontFamily: 'CharlevoixPro',
                          color: nestDarkText,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 16),

                      const Text(
                        'Workspace',
                        style: TextStyle(
                          fontFamily: 'CharlevoixPro',
                          color: nestSecondaryText,
                        ),
                      ),
                      Text(
                        widget.workspaceName,
                        style: const TextStyle(
                          fontFamily: 'CharlevoixPro',
                          color: nestDarkText,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        widget.workspaceSubline,
                        style: const TextStyle(
                          fontFamily: 'CharlevoixPro',
                          color: AppTheme.secondaryText,
                          fontSize: 14,
                          height: 1.35,
                        ),
                      ),

                      const SizedBox(height: 16),

                      const Text(
                        'What this workspace offers',
                        style: TextStyle(
                          fontFamily: 'CharlevoixPro',
                          color: nestSecondaryText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...benefits.map((b) => _buildOfferTile(b)),

                      const SizedBox(height: 16),

                      const Text(
                        'Date',
                        style: TextStyle(
                          fontFamily: 'CharlevoixPro',
                          color: nestSecondaryText,
                        ),
                      ),
                      Text(
                        displayDate,
                        style: const TextStyle(
                          fontFamily: 'CharlevoixPro',
                          color: nestDarkText,
                          fontSize: 16,
                        ),
                      ),

                      const SizedBox(height: 16),

                      const Text(
                        'Time',
                        style: TextStyle(
                          fontFamily: 'CharlevoixPro',
                          color: nestSecondaryText,
                        ),
                      ),
                      Text(
                        displayTime,
                        style: const TextStyle(
                          fontFamily: 'CharlevoixPro',
                          color: nestDarkText,
                          fontSize: 16,
                        ),
                      ),

                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 16),

                      // ✅ Hide checkbox if not eligible
                      if (eligible) ...[
                        _buildBringingChildCheckbox(),
                        const SizedBox(height: 24),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // ✅ Buttons area NOT translucent
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: _isLoadingEligibility
                  ? const SizedBox(
                height: 50,
                child: Center(child: CircularProgressIndicator()),
              )
                  : (eligible ? _buildActionButtons(context) : _buildDiscoverOptionsButton()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfferTile(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          const Icon(Icons.check, color: nestDarkText, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: 'CharlevoixPro',
                color: nestDarkText,
              ),
            ),
          ),
        ],
      ),
    );
  }

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
          style: TextStyle(
            fontFamily: 'CharlevoixPro',
            color: nestDarkText,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildDiscoverOptionsButton() {
    return SizedBox(
      height: 50,
      width: double.infinity,
      child: NestPrimaryButton(
        text: 'Discover Options',
        onPressed: _goToMembership,
        backgroundColor: const Color(0xFFFF5757),
        textColor: Colors.white,
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 50,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: nestRed),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
              ),
              child: const Text(
                'CANCEL',
                style: TextStyle(
                  fontFamily: 'CharlevoixPro',
                  color: nestRed,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 50,
            child: NestPrimaryButton(
              text: 'CONFIRM BOOKING',
              onPressed: () => Navigator.of(context).pop(true),
              backgroundColor: nestGreen,
              textColor: nestDarkText,
            ),
          ),
        ),
      ],
    );
  }
}
