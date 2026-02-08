import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nest_app/widgets/nest_button.dart';

import 'package:nest_app/widgets/nest_app_bar.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/error_handler.dart';
import '../booking/models/booking_models.dart';
import '../booking/widgets/calendar_widget.dart';
import '../booking/screens/workspace_map_screen.dart';
import '../booking/widgets/add_extras_bottom_sheet.dart';
import '../booking/widgets/meeting_room_selection_sheet.dart';
import '../membership/membership_screen.dart';
import '../profile/profile_screen.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final supabase = Supabase.instance.client;

  final DateTime firstAvailableDate = DateTime(2026, 3, 17);
  late DateTime selectedDate;
  String? selectedTimeSlot;
  String? selectedPreference;

  late Map<DateTime, OccupancyStatus> _occupancyMap;

  bool _loadingWorkspaces = true;
  String? _workspacesError;
  List<_Workspace> _workspaces = [];

  bool _loadingSlotCounts = false;

  /// number of bookings per workspace in the selected slot
  Map<int, int> _bookedCountByWorkspaceId = {};

  /// meeting rooms that have a PRIVATE booking in the selected slot
  Set<int> _privateBookedMeetingRoomIds = {};

  final List<String> _allTimeSlots = const [
    '9-12',
    '12-15',
    '15-18',
    'Full Day'
  ];
  final List<String> preferences = const ['Quiet Zone', 'Social Area'];

  static const Color _selectedChipPink = Color(0xFFF87CC8);

  bool _passOnlyFullDay = false;

  /// Read from public.users (source of truth for house rules + membership type)
  String? _membershipType; // e.g. 'full', 'regular', 'daypass', 'none'
  String? _membershipStatus; // e.g. 'active'
  bool _houseRulesAccepted = false;

  static const int _dayPassMaxFullDays = 3;

  // ---- Copied-style constants for the "already active" dialog (keep consistent) ----
  static const Color _accentPink = Color(0xFFF87CC8);
  static const Color _actionYellow = Color(0xFFFFDE59);
  static const double _actionButtonHeight = 44;

  // If you have these elsewhere, you can keep them the same here:
  static const String _nestEmail = 'hello@nest.com';
  static const String _nestPhone = '+49 000 000000';

  @override
  void initState() {
    super.initState();
    selectedDate = firstAvailableDate;
    _occupancyMap = HashMap();
    _loadWorkspaces();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadMyUserFlags();
      await _refreshEntitlementForSelectedDate();
    });
  }

  // ----------------------------
  // Auth / logout
  // ----------------------------

  Future<void> _confirmAndLogout() async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Logout?',
                style: TextStyle(fontFamily: 'SweetAndSalty')),
            content: const Text('Are you sure you want to log out?',
                style: TextStyle(fontFamily: 'CharlevoixPro')),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel',
                    style: TextStyle(fontFamily: 'CharlevoixPro')),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Logout',
                    style: TextStyle(fontFamily: 'CharlevoixPro')),
              ),
            ],
          ),
        ) ??
        false;

    if (!ok) return;

    await supabase.auth.signOut();
    if (!mounted) return;

    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  // ----------------------------
  // Date helpers
  // ----------------------------

  DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  bool _isWeekend(DateTime day) => day.weekday == 6 || day.weekday == 7;

  bool _isHolidayInHamburg2026(DateTime day) {
    final holidays = [
      DateTime(2026, 1, 1),
      DateTime(2026, 4, 3),
      DateTime(2026, 4, 6),
      DateTime(2026, 5, 1),
      DateTime(2026, 5, 14),
      DateTime(2026, 5, 25),
      DateTime(2026, 10, 3),
      DateTime(2026, 10, 31),
      DateTime(2026, 12, 25),
    ];
    return holidays.any(
        (h) => h.year == day.year && h.month == day.month && h.day == day.day);
  }

  bool isDayEnabled(DateTime day) {
    final normalizedDay = _dayOnly(day);
    if (normalizedDay.isBefore(firstAvailableDate)) return false;

    // Opening party
    if (normalizedDay.year == 2026 &&
        normalizedDay.month == 3 &&
        normalizedDay.day == 16) {
      return false;
    }

    if (_isWeekend(day)) return false;
    if (_isHolidayInHamburg2026(day)) return false;
    return true;
  }

  ({DateTime startLocal, DateTime endLocal}) _slotToRangeLocal(
      DateTime day, String slot) {
    final d = _dayOnly(day);
    switch (slot) {
      case '9-12':
        return (
          startLocal: DateTime(d.year, d.month, d.day, 9),
          endLocal: DateTime(d.year, d.month, d.day, 12)
        );
      case '12-15':
        return (
          startLocal: DateTime(d.year, d.month, d.day, 12),
          endLocal: DateTime(d.year, d.month, d.day, 15)
        );
      case '15-18':
        return (
          startLocal: DateTime(d.year, d.month, d.day, 15),
          endLocal: DateTime(d.year, d.month, d.day, 18)
        );
      case 'Full Day':
      default:
        return (
          startLocal: DateTime(d.year, d.month, d.day, 9),
          endLocal: DateTime(d.year, d.month, d.day, 18)
        );
    }
  }

  bool _isFullDayRange(DateTime startLocal, DateTime endLocal) {
    return startLocal.year == endLocal.year &&
        startLocal.month == endLocal.month &&
        startLocal.day == endLocal.day &&
        startLocal.hour == 9 &&
        startLocal.minute == 0 &&
        endLocal.hour == 18 &&
        endLocal.minute == 0;
  }

  // ----------------------------
  // Load user flags (house rules + membership)
  // ----------------------------

  Future<void> _loadMyUserFlags() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final row = await supabase
          .from('users')
          .select('membership_type,membership_status,house_rules_accepted')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;

      final type =
          (row?['membership_type'] ?? '').toString().trim().toLowerCase();
      final status =
          (row?['membership_status'] ?? '').toString().trim().toLowerCase();
      final accepted = (row?['house_rules_accepted'] == true);

      setState(() {
        _membershipType = type.isEmpty ? null : type;
        _membershipStatus = status.isEmpty ? null : status;
        _houseRulesAccepted = accepted;
      });
    } catch (e) {
      // Log error but don't show to user (non-critical, defaults will be used)
      debugPrint('Failed to load user membership flags: $e');
    }
  }

  bool get _isDayPassActive =>
      (_membershipStatus ?? '').toLowerCase() == 'active' &&
      (_membershipType ?? '').toLowerCase() == 'daypass';

  /// Your “premium” rule for private meeting room bookings
  bool get _isFullOrPartTimeActive {
    final status = (_membershipStatus ?? '').toString().trim().toLowerCase();
    final type = (_membershipType ?? '').toString().trim().toLowerCase();
    return status == 'active' &&
        (type == 'full' || type == 'part-time' || type == 'part_time');
  }

  // ----------------------------
  // MeetingRoomSelectionSheet membership mapping
  // ----------------------------

  UserMembership _enumByPreferredNames(List<String> preferred) {
    final values = UserMembership.values;
    for (final want in preferred) {
      final w = want.trim().toLowerCase();
      for (final v in values) {
        if (v.name.toLowerCase() == w) return v;
      }
    }
    return values.first;
  }

  /// Fix: MeetingRoomSelectionSheet likely expects `premium` (not `full`) to enable "entire room".
  UserMembership _membershipForMeetingRoomSheet() {
    final status = (_membershipStatus ?? '').trim().toLowerCase();
    final type = (_membershipType ?? '').trim().toLowerCase();

    if (status != 'active') {
      return _enumByPreferredNames(
          ['none', 'guest', 'daypass', 'regular', 'premium', 'full']);
    }

    if (type == 'full' || type == 'part-time' || type == 'part_time') {
      // Prefer premium first so the sheet enables “entire room” if it uses premium logic.
      return _enumByPreferredNames(['premium', 'full', 'regular']);
    }

    if (type == 'regular') {
      return _enumByPreferredNames(['regular']);
    }

    return _enumByPreferredNames(['regular']);
  }

  // ----------------------------
  // RPC: can_user_book
  // ----------------------------

  Future<Map<String, dynamic>> _canUserBookForRange({
    required DateTime startLocal,
    required DateTime endLocal,
  }) async {
    final startUtc = startLocal.toUtc().toIso8601String();
    final endUtc = endLocal.toUtc().toIso8601String();

    final res = await supabase.rpc('can_user_book', params: {
      'p_start': startUtc,
      'p_end': endUtc,
    });

    if (res is Map) return Map<String, dynamic>.from(res);
    if (res is List && res.isNotEmpty && res.first is Map) {
      return Map<String, dynamic>.from(res.first as Map);
    }
    if (res is bool) return {'allowed': res};
    return {'allowed': false, 'reason': 'Please try again.'};
  }

  Future<Map<String, dynamic>> _canUserBookSelectedSlot() async {
    final slot = selectedTimeSlot;
    if (slot == null) {
      return {'allowed': false, 'reason': 'Please select a time slot first.'};
    }

    final range = _slotToRangeLocal(selectedDate, slot);
    return _canUserBookForRange(
        startLocal: range.startLocal, endLocal: range.endLocal);
  }

  Future<void> _refreshEntitlementForSelectedDate() async {
    final range = _slotToRangeLocal(selectedDate, 'Full Day');

    try {
      final res = await _canUserBookForRange(
          startLocal: range.startLocal, endLocal: range.endLocal);

      final entitlement =
          (res['entitlement'] ?? '').toString().trim().toLowerCase();
      final passOnlyFromRpc = entitlement == 'pass';

      if (!mounted) return;

      final passOnly = passOnlyFromRpc || _isDayPassActive;

      setState(() {
        _passOnlyFullDay = passOnly;
      });

      if (passOnly && selectedTimeSlot != 'Full Day') {
        setState(() => selectedTimeSlot = 'Full Day');
        await _loadSlotCounts();
      }
    } catch (e) {
      debugPrint('Failed to check day pass entitlement: $e');
      if (!mounted) return;
      setState(() {
        _passOnlyFullDay = _isDayPassActive;
      });
    }
  }

  // ----------------------------
  // House rules dialog + navigation to Profile
  // ----------------------------

  static const String _houseRulesText = 'House Rules\n\n'
      '• Be kind and respectful to all parents and children.\n'
      '• Keep phone calls quiet and use headphones.\n'
      '• Please clean up your workspace and any play area you used.\n'
      '• Food and drinks only in designated areas.\n\n'
      'To book a workspace, please accept the house rules in your Profile.';

  Future<void> _showHouseRulesGateDialog() async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Please accept the house rules to book',
                style: TextStyle(
                  fontFamily: 'CharlevoixPro',
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.darkText,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: SingleChildScrollView(
                  child: const Text(
                    _houseRulesText,
                    style: TextStyle(
                      fontFamily: 'CharlevoixPro',
                      fontSize: 14,
                      color: AppTheme.secondaryText,
                      height: 1.35,
                    ),
                    textAlign: TextAlign.left,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.of(ctx).pop();
                          if (!mounted) return;
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const ProfileScreen()),
                          );
                          await _loadMyUserFlags();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _actionYellow,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(50)),
                        ),
                        child: const Text(
                          'Open Profile',
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontWeight: FontWeight.w700,
                            color: AppTheme.darkText,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Close',
                      style: TextStyle(fontFamily: 'CharlevoixPro')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ----------------------------
  // Day pass usage check (3 confirmed full-day bookings)
  // ----------------------------

  Future<int> _countConfirmedFullDayBookingsThisYear() async {
    final user = supabase.auth.currentUser;
    if (user == null) return 0;

    final now = DateTime.now();
    final startYear = DateTime(now.year, 1, 1).toUtc().toIso8601String();
    final startNextYear =
        DateTime(now.year + 1, 1, 1).toUtc().toIso8601String();

    try {
      final rows = await supabase
          .from('bookings')
          .select('start_time,end_time,status')
          .eq('user_id', user.id)
          .gte('start_time', startYear)
          .lt('start_time', startNextYear);

      int count = 0;
      for (final r in (rows as List)) {
        final map = r as Map<String, dynamic>;
        final status = (map['status'] ?? '').toString().trim().toLowerCase();
        if (status != 'confirmed') continue;

        final startLocal =
            DateTime.parse(map['start_time'] as String).toLocal();
        final endLocal = DateTime.parse(map['end_time'] as String).toLocal();

        if (_isFullDayRange(startLocal, endLocal)) count++;
      }
      return count;
    } catch (e) {
      debugPrint('Failed to count day pass bookings: $e');
      return 0; // Return 0 to allow booking attempt
    }
  }

  Future<void> _showDayPassLimitDialog() async {
    await _showAlreadyActiveMembershipDialog(
      me: {
        'membership_type': _membershipType ?? 'daypass',
        'membership_status': _membershipStatus ?? 'active',
      },
      overrideTitle: 'Day Pass',
      overrideBody:
          'You’ve already used all $_dayPassMaxFullDays Full Day bookings included in your Day Pass.\n\n'
          'If you’d like to book more days, please get another pass or upgrade your membership.',
    );
  }

  // ----------------------------
  // Membership-style dialog (adapted from MembershipScreen)
  // ----------------------------

  String _prettyMembershipType(String raw) {
    final t = raw.trim().toLowerCase();
    switch (t) {
      case 'full':
        return 'Full';
      case 'regular':
        return 'Regular';
      case 'part-time':
      case 'part_time':
        return 'Part-time';
      case 'light':
        return 'Light';
      case 'daypass':
      case 'day_pass':
        return 'Day Pass';
      default:
        if (t.isEmpty) return '';
        return t[0].toUpperCase() + t.substring(1);
    }
  }

  ButtonStyle _pillOutlinedStyle() => OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
        side: BorderSide(color: Colors.black.withValues(alpha: 0.18)),
        padding: const EdgeInsets.symmetric(vertical: 12),
      );

  ButtonStyle _pillFilledStyle(Color bg) => ElevatedButton.styleFrom(
        backgroundColor: bg,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
        padding: const EdgeInsets.symmetric(vertical: 12),
      );

  TextStyle _pillTextStyle({Color? color}) => TextStyle(
        fontFamily: 'Montserrat',
        fontWeight: FontWeight.w600,
        color: color ?? AppTheme.darkText,
      );

  Future<void> _showAlreadyActiveMembershipDialog({
    Map<String, dynamic>? me,
    String? overrideTitle,
    String? overrideBody,
  }) async {
    if (!mounted) return;

    final type =
        _prettyMembershipType((me?['membership_type'] ?? '').toString());
    final status =
        (me?['membership_status'] ?? '').toString().trim().toLowerCase();

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                overrideTitle ?? 'NEST Membership',
                style: const TextStyle(
                  fontFamily: 'SweetAndSalty',
                  fontSize: 22,
                  color: AppTheme.darkText,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                overrideBody ?? 'You already have an active membership',
                style: const TextStyle(
                  fontFamily: 'CharlevoixPro',
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.darkText,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              if (status == 'active' && type.isNotEmpty)
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: const TextStyle(
                      fontFamily: 'CharlevoixPro',
                      fontSize: 14,
                      color: AppTheme.secondaryText,
                      height: 1.3,
                    ),
                    children: [
                      const TextSpan(text: 'Current plan: '),
                      TextSpan(
                        text: type,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: _accentPink,
                        ),
                      ),
                    ],
                  ),
                )
              else
                const Text(
                  'Your membership is currently active.',
                  style: TextStyle(
                    fontFamily: 'CharlevoixPro',
                    fontSize: 14,
                    color: AppTheme.secondaryText,
                    height: 1.3,
                  ),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 14),
              const Text(
                'Interested in another membership or an upgrade?\nWe’ll be happy to consult you on the best options.',
                style: TextStyle(
                  fontFamily: 'CharlevoixPro',
                  fontSize: 14,
                  color: AppTheme.secondaryText,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: Colors.black.withValues(alpha: 0.08)),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                      color: Colors.black.withValues(alpha: 0.06),
                    )
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.email, size: 18, color: AppTheme.darkText),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _nestEmail,
                            style: TextStyle(
                                fontFamily: 'CharlevoixPro',
                                color: AppTheme.darkText),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: const [
                        Icon(Icons.phone, size: 18, color: AppTheme.darkText),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _nestPhone,
                            style: TextStyle(
                                fontFamily: 'CharlevoixPro',
                                color: AppTheme.darkText),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: _actionButtonHeight,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.of(ctx).pop();
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) => const MembershipScreen()),
                                );
                              },
                              style: _pillFilledStyle(_actionYellow),
                              child:
                                  Text('Memberships', style: _pillTextStyle()),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SizedBox(
                            height: _actionButtonHeight,
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              style: _pillOutlinedStyle(),
                              child: Text('Close', style: _pillTextStyle()),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: _actionButtonHeight,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => const MembershipScreen()));
                        },
                        style: _pillOutlinedStyle(),
                        child: Text('Open website', style: _pillTextStyle()),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Center(
                child: SizedBox(
                  width: 200,
                  child: NestPrimaryButton(
                    text: 'Close',
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ----------------------------
  // Gatekeeper used by Select + View on map
  // ----------------------------

  Future<bool> _ensureCanEnterBookingFlow() async {
    if (selectedTimeSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a time slot first.'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    await _loadMyUserFlags();
    if (!mounted) return false;

    if (_houseRulesAccepted != true) {
      await _showHouseRulesGateDialog();
      return false;
    }

    if (_isDayPassActive && selectedTimeSlot != 'Full Day') {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Full Day only',
              style: TextStyle(fontFamily: 'SweetAndSalty')),
          content: const Text(
            'Day Pass bookings are available for Full Day only.',
            style: TextStyle(fontFamily: 'CharlevoixPro'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                setState(() => selectedTimeSlot = 'Full Day');
              },
              child: const Text('Select Full Day',
                  style: TextStyle(fontFamily: 'CharlevoixPro')),
            ),
          ],
        ),
      );
      return false;
    }

    if (_isDayPassActive && selectedTimeSlot == 'Full Day') {
      final used = await _countConfirmedFullDayBookingsThisYear();
      if (used >= _dayPassMaxFullDays) {
        await _showDayPassLimitDialog();
        return false;
      }
    }

    try {
      final can = await _canUserBookSelectedSlot();
      if (!mounted) return false;

      if (can['allowed'] != true) {
        final reason = can['reason']?.toString() ?? '';

        if (reason.toLowerCase().contains('house rule')) {
          await _showHouseRulesGateDialog();
          return false;
        }

        _showNeedsEntitlementSnack(reason);
        return false;
      }
    } catch (e) {
      if (!mounted) return false;
      ErrorHandler.showError(
        context,
        e,
        userMessage: 'Unable to verify booking permissions. Please try again.',
      );
      return false;
    }

    return true;
  }

  void _showNeedsEntitlementSnack(String? reason) {
    final text = (reason == null || reason.trim().isEmpty)
        ? 'To book a space, please activate a membership or buy a pass.'
        : reason.trim();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: Colors.red,
        action: SnackBarAction(
          label: 'Memberships',
          textColor: Colors.white,
          onPressed: () {
            Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MembershipScreen()));
          },
        ),
      ),
    );
  }

  // ----------------------------
  // Overlap pre-check
  // ----------------------------

  Future<bool> _userHasOverlapForSlot({
    required DateTime day,
    required String slot,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) return false;

    final range = _slotToRangeLocal(day, slot);
    final startUtc = range.startLocal.toUtc().toIso8601String();
    final endUtc = range.endLocal.toUtc().toIso8601String();

    final rows = await supabase
        .from('bookings')
        .select('id')
        .eq('user_id', user.id)
        .lt('start_time', endUtc)
        .gt('end_time', startUtc)
        .limit(1);

    return (rows as List).isNotEmpty;
  }

  void _showOverlapSnack() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            'You already have a booking in this time slot. Please choose another slot.'),
        backgroundColor: Colors.red,
      ),
    );
  }

  bool _looksLikeOverlapException(Object e) {
    final msg = e.toString().toLowerCase();
    return msg.contains('23p01') ||
        msg.contains('no_overlapping_bookings_per_user') ||
        msg.contains('exclusion constraint') ||
        msg.contains('conflicting key value');
  }

  // ----------------------------
  // Data loading
  // ----------------------------

  Future<void> _loadWorkspaces() async {
    setState(() {
      _loadingWorkspaces = true;
      _workspacesError = null;
    });

    try {
      final rows = await supabase
          .from('workspaces')
          .select(
              'id,name,workspace_type,capacity,is_bookable,workspace_description')
          .eq('is_bookable', true)
          .order('id', ascending: true);

      final list = (rows as List)
          .map((r) => _Workspace.fromJson(r as Map<String, dynamic>))
          .toList();

      if (!mounted) return;
      setState(() {
        _workspaces = list;
        _loadingWorkspaces = false;
      });

      await _loadMonthOccupancy(selectedDate);

      if (selectedTimeSlot != null) {
        await _loadSlotCounts();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _workspacesError = e.toString();
        _loadingWorkspaces = false;
      });
    }
  }

  Future<void> _loadMonthOccupancy(DateTime dayInMonth) async {
    final monthStart = DateTime(dayInMonth.year, dayInMonth.month, 1);
    final nextMonthStart = DateTime(dayInMonth.year, dayInMonth.month + 1, 1);

    final totalCapacityPerDay = _workspaces
        .fold<int>(0, (sum, w) => sum + (w.capacity <= 0 ? 1 : w.capacity))
        .clamp(1, 999999);

    try {
      final rows = await supabase
          .from('bookings')
          .select('start_time')
          .gte('start_time', monthStart.toUtc().toIso8601String())
          .lt('start_time', nextMonthStart.toUtc().toIso8601String());

      final Map<DateTime, int> counts = HashMap();

      for (final r in (rows as List)) {
        final map = r as Map<String, dynamic>;
        final start = DateTime.parse(map['start_time'] as String).toLocal();
        final d = _dayOnly(start);
        counts[d] = (counts[d] ?? 0) + 1;
      }

      final Map<DateTime, OccupancyStatus> newMap = HashMap();
      for (var day = monthStart;
          day.isBefore(nextMonthStart);
          day = day.add(const Duration(days: 1))) {
        final d = _dayOnly(day);

        if (!isDayEnabled(d)) {
          newMap[d] = OccupancyStatus.notAvailable;
          continue;
        }

        final count = counts[d] ?? 0;
        final pctBooked = count / totalCapacityPerDay;

        if (count >= totalCapacityPerDay) {
          newMap[d] = OccupancyStatus.full;
        } else if (pctBooked >= 0.5) {
          newMap[d] = OccupancyStatus.medium;
        } else {
          newMap[d] = OccupancyStatus.low;
        }
      }

      if (!mounted) return;
      setState(() => _occupancyMap = newMap);
    } catch (e) {
      debugPrint('Failed to load calendar occupancy: $e');
      // Non-critical error - calendar will show without occupancy indicators
    }
  }

  Future<void> _loadSlotCounts() async {
    if (selectedTimeSlot == null) return;

    setState(() => _loadingSlotCounts = true);

    final range = _slotToRangeLocal(selectedDate, selectedTimeSlot!);
    final startUtc = range.startLocal.toUtc().toIso8601String();
    final endUtc = range.endLocal.toUtc().toIso8601String();

    try {
      final rows = await supabase
          .from('bookings')
          .select('workspace_id,meeting_booking_type')
          .lt('start_time', endUtc)
          .gt('end_time', startUtc);

      final Map<int, int> counts = {};
      final Set<int> privateRooms = {};

      for (final r in (rows as List)) {
        final map = r as Map<String, dynamic>;
        final wid = (map['workspace_id'] as num).toInt();
        final type =
            (map['meeting_booking_type'] ?? '').toString().trim().toLowerCase();

        counts[wid] = (counts[wid] ?? 0) + 1;
        if (type == 'private') privateRooms.add(wid);
      }

      if (!mounted) return;
      setState(() {
        _bookedCountByWorkspaceId = counts;
        _privateBookedMeetingRoomIds = privateRooms;
        _loadingSlotCounts = false;
      });
    } catch (e) {
      debugPrint('Failed to load slot availability: $e');
      if (!mounted) return;
      setState(() => _loadingSlotCounts = false);
      // Non-critical - workspace selection will still work without live counts
    }
  }

  // Preference filtering
  List<_Workspace> _applyPreferenceFilter(List<_Workspace> all) {
    final pref = selectedPreference;
    if (pref == null) return all;

    if (pref == 'Quiet Zone') {
      return all
          .where((w) =>
              w.workspaceType == 'FOCUS_BOX' ||
              w.workspaceType == 'MEETING_ROOM')
          .toList();
    } else {
      return all.where((w) => w.workspaceType != 'FOCUS_BOX').toList();
    }
  }

  int _remainingForWorkspace(_Workspace w) {
    final isMeetingRoom = w.workspaceType == 'MEETING_ROOM';
    final privateBooked =
        isMeetingRoom && _privateBookedMeetingRoomIds.contains(w.id);

    // Important: private booking removes ALL 4 seats from availability
    if (privateBooked) return 0;

    final booked = _bookedCountByWorkspaceId[w.id] ?? 0;
    final capacity = w.capacity <= 0 ? 1 : w.capacity;
    return (capacity - booked).clamp(0, capacity);
  }

  int _remainingForCategory(List<_Workspace> workspacesOfType) {
    int sum = 0;
    for (final w in workspacesOfType) {
      sum += _remainingForWorkspace(w);
    }
    return sum;
  }

  String _categoryLabel(String workspaceType) {
    switch (workspaceType) {
      case 'FOCUS_BOX':
        return 'Focus Box';
      case 'SPIELFELDRAND_SEAT':
        return 'Spielfeldrand Seat';
      case 'STANDING_DESK':
        return 'Standing Desk';
      case 'MEETING_ROOM':
        return 'Meeting Room';
      case 'SHARED_DESK':
        return 'Shared Desk';
      default:
        return workspaceType;
    }
  }

  String _emojiForWorkspaceType(String workspaceType) {
    switch (workspaceType) {
      case 'FOCUS_BOX':
        return '🎧';
      case 'SPIELFELDRAND_SEAT':
        return '👶';
      case 'STANDING_DESK':
        return '🧍';
      case 'MEETING_ROOM':
        return '🛋️';
      case 'SHARED_DESK':
        return '🪑';
      default:
        return '✨';
    }
  }

  List<String> _benefitsForWorkspaceType(String workspaceType) {
    switch (workspaceType) {
      case 'FOCUS_BOX':
        return const ['Quiet focus', 'Privacy', 'Power outlet'];
      case 'SPIELFELDRAND_SEAT':
        return const ['Near play area', 'Easy supervision', 'Flexible seating'];
      case 'STANDING_DESK':
        return const ['Stand & stretch', 'Quick sessions', 'Good posture'];
      case 'MEETING_ROOM':
        return const [
          'Comfortable benches',
          'Talk & collaborate',
          'More privacy'
        ];
      case 'SHARED_DESK':
        return const ['Big shared table', 'Community vibe', 'Fast Wi‑Fi'];
      default:
        return const ['Fast Wi‑Fi', 'Power outlet', 'Comfortable seat'];
    }
  }

  Future<void> _showBookingConfirmedDialog({
    required String workspaceName,
    required DateTime startLocal,
    required DateTime endLocal,
  }) async {
    final localizations = MaterialLocalizations.of(context);
    final date = localizations.formatFullDate(startLocal);
    final time =
        '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(startLocal))} – ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(endLocal))}';

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Booking confirmed!',
            style: TextStyle(fontFamily: 'SweetAndSalty')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(workspaceName,
                style: const TextStyle(
                    fontFamily: 'CharlevoixPro', fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(date, style: const TextStyle(fontFamily: 'CharlevoixPro')),
            Text(time, style: const TextStyle(fontFamily: 'CharlevoixPro')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child:
                const Text('OK', style: TextStyle(fontFamily: 'CharlevoixPro')),
          )
        ],
      ),
    );
  }

  // ----------------------------
  // Booking flow
  // ----------------------------

  Future<void> _quickSelectAndBook(List<_Workspace> candidates) async {
    if (selectedTimeSlot == null) return;

    final allowed = await _ensureCanEnterBookingFlow();
    if (!allowed) return;

    try {
      final hasOverlap = await _userHasOverlapForSlot(
          day: selectedDate, slot: selectedTimeSlot!);
      if (!mounted) return;
      if (hasOverlap) {
        _showOverlapSnack();
        return;
      }
    } catch (e) {
      debugPrint('Failed to check for booking overlap: $e');
      // Continue with booking flow - server will catch overlap if it exists
    }

    await _loadSlotCounts();
    if (!mounted) return;

    final available = candidates.where((w) {
      if (w.workspaceType == 'MEETING_ROOM' &&
          _privateBookedMeetingRoomIds.contains(w.id)) {
        return false;
      }
      return _remainingForWorkspace(w) > 0;
    }).toList();

    if (available.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('No seats left in this category for the selected slot.'),
            backgroundColor: Colors.red),
      );
      return;
    }

    final chosen = available.first;
    final range = _slotToRangeLocal(selectedDate, selectedTimeSlot!);

    MeetingBookingType? meetingType;
    String meetingChoiceLabel = '';

    if (chosen.workspaceType == 'MEETING_ROOM') {
      // Make bottom sheet tall enough to show both options without scrolling (most devices)
      final selection = await showModalBottomSheet<MeetingBookingType>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => MeetingRoomSelectionSheet(
          currentUserMembership: _membershipForMeetingRoomSheet(),
        ),
      );

      if (selection == null) return;
      if (!mounted) return;
      meetingType = selection;

      meetingChoiceLabel = meetingType == MeetingBookingType.private
          ? 'Entire room (Private)'
          : 'Single seat (Shared)';

      if (meetingType == MeetingBookingType.private) {
        if (!_isFullOrPartTimeActive) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Book Entire Room is only available for Premium members (Full or Part‑Time).'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        final alreadyBookedSeats = _bookedCountByWorkspaceId[chosen.id] ?? 0;
        if (alreadyBookedSeats > 0) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'You can only book the meeting room privately if no seats are booked yet.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }
    }

    final displayName = chosen.workspaceType == 'MEETING_ROOM' &&
            meetingChoiceLabel.isNotEmpty
        ? '${chosen.name} ${_emojiForWorkspaceType(chosen.workspaceType)} • $meetingChoiceLabel'
        : '${chosen.name} ${_emojiForWorkspaceType(chosen.workspaceType)}';

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddExtrasBottomSheet(
        workspaceName:
            displayName, // shows chosen shared/private in the overview
        workspaceSubline: chosen.description ?? '',
        workspaceBenefits: _benefitsForWorkspaceType(chosen.workspaceType),
        startLocal: range.startLocal,
        endLocal: range.endLocal,
      ),
    );

    if (confirmed != true || !mounted) return;

    final user = supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please log in again.'), backgroundColor: Colors.red),
      );
      return;
    }

    final startUtc = range.startLocal.toUtc().toIso8601String();
    final endUtc = range.endLocal.toUtc().toIso8601String();

    try {
      final payload = <String, dynamic>{
        'workspace_id': chosen.id,
        'user_id': user.id,
        'start_time': startUtc,
        'end_time': endUtc,
      };

      if (chosen.workspaceType == 'MEETING_ROOM' && meetingType != null) {
        payload['meeting_booking_type'] =
            meetingType == MeetingBookingType.private ? 'private' : 'shared';
      }

      await supabase.from('bookings').insert(payload).select('id').single();

      await _loadSlotCounts();
      await _loadMonthOccupancy(selectedDate);

      await _showBookingConfirmedDialog(
        workspaceName: displayName, // also shows chosen shared/private here
        startLocal: range.startLocal,
        endLocal: range.endLocal,
      );
    } catch (e) {
      if (!mounted) return;

      final userMessage = _looksLikeOverlapException(e)
          ? 'You already have a booking in this time slot. Please choose another slot.'
          : 'Booking failed. Please try again.';

      ErrorHandler.showError(context, e, userMessage: userMessage);
    }
  }

  // ----------------------------
  // UI helpers
  // ----------------------------

  List<String> get _visibleTimeSlots => (_passOnlyFullDay || _isDayPassActive)
      ? const ['Full Day']
      : _allTimeSlots;

  @override
  Widget build(BuildContext context) {
    final filtered = _applyPreferenceFilter(_workspaces);

    final Map<String, List<_Workspace>> byType = {};
    for (final w in filtered) {
      byType.putIfAbsent(w.workspaceType, () => []).add(w);
    }

    final types = byType.keys.toList()
      ..sort((a, b) => _categoryLabel(a).compareTo(_categoryLabel(b)));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: NestAppBar(
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout, color: AppTheme.darkText),
            onPressed: _confirmAndLogout,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'Find your perfect spot!',
                style: TextStyle(
                    fontFamily: 'SweetAndSalty',
                    fontSize: 28,
                    color: AppTheme.darkText),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 6),
            const Center(
              child: Text(
                'Book a workspace that fits your needs',
                style: TextStyle(
                    fontFamily: 'CharlevoixPro',
                    fontSize: 14,
                    color: AppTheme.secondaryText),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "Choose your date",
              style: TextStyle(
                fontFamily: 'CharlevoixPro',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkText,
              ),
            ),
            const SizedBox(height: 16),
            CalendarWidget(
              selectedDate: selectedDate,
              onDateSelected: (date) async {
                setState(() => selectedDate = date);
                await _loadMonthOccupancy(date);

                await _loadMyUserFlags();
                await _refreshEntitlementForSelectedDate();

                if (selectedTimeSlot != null) await _loadSlotCounts();
              },
              occupancyMap: _occupancyMap,
              firstAvailableDate: firstAvailableDate,
              isDayEnabled: isDayEnabled,
            ),
            const SizedBox(height: 40),
            const Text(
              "Select Time Slot",
              style: TextStyle(
                fontFamily: 'CharlevoixPro',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkText,
              ),
            ),
            const SizedBox(height: 10),
            if (_passOnlyFullDay || _isDayPassActive)
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Text(
                  'Day Pass bookings can be used for Full Day bookings only.',
                  style: TextStyle(
                      fontFamily: 'CharlevoixPro',
                      fontSize: 13,
                      color: AppTheme.secondaryText),
                ),
              ),
            _buildFilterChips(_visibleTimeSlots, selectedTimeSlot, (val) async {
              if ((_passOnlyFullDay || _isDayPassActive) &&
                  val != null &&
                  val != 'Full Day') {
                return;
              }

              setState(() => selectedTimeSlot = val);
              if (val != null) await _loadSlotCounts();
            }),
            const SizedBox(height: 40),
            const Text(
              "Preferences (optional)",
              style: TextStyle(
                fontFamily: 'CharlevoixPro',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkText,
              ),
            ),
            const SizedBox(height: 16),
            _buildFilterChips(preferences, selectedPreference, (val) {
              setState(() => selectedPreference = val);
              if (selectedTimeSlot != null) _loadSlotCounts();
            }),
            const SizedBox(height: 40),
            const Text(
              "Available Workspaces",
              style: TextStyle(
                fontFamily: 'CharlevoixPro',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkText,
              ),
            ),
            const SizedBox(height: 16),
            if (selectedTimeSlot == null)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  "Please select a time slot to see available categories.",
                  style: TextStyle(
                      fontFamily: 'CharlevoixPro',
                      fontSize: 14,
                      color: AppTheme.secondaryText),
                ),
              )
            else if (_loadingWorkspaces)
              const Center(
                  child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator()))
            else if (_workspacesError != null)
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text(_workspacesError!,
                    style: const TextStyle(
                        fontFamily: 'CharlevoixPro', color: Colors.red)),
              )
            else
              Builder(
                builder: (_) {
                  final visibleTypes = types.where((type) {
                    if (_loadingSlotCounts) return true;
                    final seats = byType[type] ?? const [];
                    return _remainingForCategory(seats) > 0;
                  }).toList();

                  if (!_loadingSlotCounts && visibleTypes.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        "No categories available for this time slot.",
                        style: TextStyle(
                            fontFamily: 'CharlevoixPro',
                            fontSize: 14,
                            color: AppTheme.secondaryText),
                      ),
                    );
                  }

                  return Column(
                    children: visibleTypes.map((type) {
                      final seats = byType[type] ?? const [];
                      final seatsLeft = _loadingSlotCounts
                          ? null
                          : _remainingForCategory(seats);
                      final benefits =
                          _benefitsForWorkspaceType(type).take(3).toList();

                      final disabled = seatsLeft != null && seatsLeft <= 0;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: Colors.black.withValues(alpha: 0.08)),
                            boxShadow: [
                              BoxShadow(
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                                color: Colors.black.withValues(alpha: 0.06),
                              )
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${_categoryLabel(type)} ${_emojiForWorkspaceType(type)}',
                                        style: const TextStyle(
                                          fontFamily: 'CharlevoixPro',
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: AppTheme.darkText,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        seatsLeft == null
                                            ? 'Checking availability…'
                                            : (seatsLeft == 1
                                                ? '1 seat left'
                                                : '$seatsLeft seats left'),
                                        style: const TextStyle(
                                          fontFamily: 'CharlevoixPro',
                                          fontSize: 13,
                                          color: AppTheme.secondaryText,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      ...benefits.map(
                                        (b) => Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 4),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text('• ',
                                                  style: TextStyle(
                                                      fontFamily:
                                                          'CharlevoixPro',
                                                      color:
                                                          AppTheme.darkText)),
                                              Expanded(
                                                child: Text(
                                                  b,
                                                  style: const TextStyle(
                                                    fontFamily: 'CharlevoixPro',
                                                    fontSize: 13,
                                                    color: AppTheme.darkText,
                                                    height: 1.25,
                                                  ),
                                                ),
                                              )
                                            ],
                                          ),
                                        ),
                                      ),
                                    ]),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 120,
                                child: Column(
                                  children: [
                                    SizedBox(
                                      width: double.infinity,
                                      height: 44,
                                      child: ElevatedButton(
                                        onPressed: disabled
                                            ? null
                                            : () => _quickSelectAndBook(seats),
                                        style: ButtonStyle(
                                          backgroundColor:
                                              WidgetStateProperty.all(
                                                  _selectedChipPink),
                                          shape: WidgetStateProperty.all(
                                            RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(24)),
                                          ),
                                        ),
                                        child: const Text(
                                          'Select',
                                          style: TextStyle(
                                            fontFamily: 'CharlevoixPro',
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 44,
                                      child: OutlinedButton(
                                        onPressed: disabled
                                            ? null
                                            : () async {
                                                if (selectedTimeSlot == null) {
                                                  return;
                                                }

                                                final allowed =
                                                    await _ensureCanEnterBookingFlow();
                                                if (!allowed) return;

                                                try {
                                                  final hasOverlap =
                                                      await _userHasOverlapForSlot(
                                                    day: selectedDate,
                                                    slot: selectedTimeSlot!,
                                                  );
                                                  if (!mounted) return;

                                                  if (hasOverlap) {
                                                    _showOverlapSnack();
                                                    return;
                                                  }
                                                } catch (e) {
                                                  debugPrint(
                                                      'Failed to check for booking overlap: $e');
                                                  // Continue - server will catch overlap if it exists
                                                }

                                                if (!mounted) return;
                                                if (!context.mounted) return;
                                                await Navigator.of(context)
                                                    .push(
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        WorkspaceMapScreen(
                                                      selectedDate:
                                                          selectedDate,
                                                      selectedTimeSlot:
                                                          selectedTimeSlot!,
                                                      selectedPreference:
                                                          selectedPreference,
                                                      selectedCategoryType:
                                                          type,
                                                    ),
                                                  ),
                                                );

                                                if (selectedTimeSlot != null) {
                                                  await _loadSlotCounts();
                                                  await _loadMonthOccupancy(
                                                      selectedDate);
                                                }
                                              },
                                        style: OutlinedButton.styleFrom(
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(24)),
                                          side: BorderSide(
                                              color: Colors.black
                                                  .withValues(alpha: 0.18)),
                                        ),
                                        child: const FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            'View on map',
                                            style: TextStyle(
                                              fontFamily: 'CharlevoixPro',
                                              fontWeight: FontWeight.w800,
                                              color: AppTheme.darkText,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
          ]),
        ),
      ),
    );
  }

  Widget _buildFilterChips(
      List<String> items, String? selectedItem, Function(String?) onSelected) {
    return Wrap(
      spacing: 10.0,
      runSpacing: 10.0,
      children: items.map((item) {
        final isSelected = item == selectedItem;

        return GestureDetector(
          onTap: () => onSelected(isSelected ? null : item),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? _selectedChipPink : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: isSelected
                      ? _selectedChipPink
                      : Colors.black.withValues(alpha: 0.08)),
              boxShadow: [
                BoxShadow(
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                  color: Colors.black.withValues(alpha: 0.06),
                )
              ],
            ),
            child: Text(
              item,
              style: TextStyle(
                fontFamily: 'CharlevoixPro',
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? Colors.white : AppTheme.darkText,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _Workspace {
  final int id;
  final String name;
  final String workspaceType;
  final int capacity;
  final bool isBookable;
  final String? description;

  _Workspace({
    required this.id,
    required this.name,
    required this.workspaceType,
    required this.capacity,
    required this.isBookable,
    required this.description,
  });

  factory _Workspace.fromJson(Map<String, dynamic> json) {
    return _Workspace(
      id: (json['id'] as num).toInt(),
      name: (json['name'] ?? '').toString(),
      workspaceType: (json['workspace_type'] ?? '').toString(),
      capacity: ((json['capacity'] as num?) ?? 1).toInt(),
      isBookable: (json['is_bookable'] ?? true) as bool,
      description: json['workspace_description']?.toString(),
    );
  }
}
