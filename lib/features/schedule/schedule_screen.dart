// lib/features/schedule/schedule_screen.dart
//
// What’s new in this version:
// - If the user’s entitlement is a PASS (Day Pass / Flexi-Pass), the time slot UI is restricted to **Full Day only**
//   (as requested). We detect this via `can_user_book` RPC and its `entitlement` field.
// - Booking entry points ("Select" and "View on map") use `can_user_book` to show a friendly reason immediately
//   (house rules not accepted, no entitlement, pass requires Full Day, etc).
// - ✅ Guest popup REMOVED from this screen (it now lives in MainScreen only)
// - Still includes overlap pre-check and friendly overlap messaging.
// - Keeps the rest of the UX changes you already had (Select button pink & above View on map, hide 0-seat categories,
//   centered NEST logo + logout, etc.)

import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nest_app/widgets/nest_app_bar.dart';
import '../../core/theme/app_theme.dart';
import '../booking/models/booking_models.dart';
import '../booking/widgets/calendar_widget.dart';
import '../booking/screens/workspace_map_screen.dart';
import '../booking/widgets/add_extras_bottom_sheet.dart';
import '../booking/widgets/meeting_room_selection_sheet.dart';
import '../membership/membership_screen.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final supabase = Supabase.instance.client;

  final DateTime firstAvailableDate = DateTime(2026, 3, 16);
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

  final List<String> _allTimeSlots = const ['9-12', '12-15', '15-18', 'Full Day'];
  final List<String> preferences = const ['Quiet Zone', 'Social Area'];

  static const Color _selectedChipPink = Color(0xFFF87CC8);

  /// Derived from `can_user_book` (RPC). If `pass`, we restrict the UI to Full Day only.
  String? _entitlement; // 'membership' | 'pass' | null
  bool _passOnlyFullDay = false;

  @override
  void initState() {
    super.initState();
    selectedDate = firstAvailableDate;
    _occupancyMap = HashMap();
    _loadWorkspaces();

    // Entitlement is user-specific; update early.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
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
        title: const Text('Logout?', style: TextStyle(fontFamily: 'SweetAndSalty')),
        content: const Text('Are you sure you want to log out?', style: TextStyle(fontFamily: 'CharlevoixPro')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(fontFamily: 'CharlevoixPro')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Logout', style: TextStyle(fontFamily: 'CharlevoixPro')),
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
    return holidays.any((h) => h.year == day.year && h.month == day.month && h.day == day.day);
  }

  bool isDayEnabled(DateTime day) {
    final normalizedDay = _dayOnly(day);
    if (normalizedDay.isBefore(firstAvailableDate)) return false;
    if (_isWeekend(day)) return false;
    if (_isHolidayInHamburg2026(day)) return false;
    return true;
  }

  ({DateTime startLocal, DateTime endLocal}) _slotToRangeLocal(DateTime day, String slot) {
    final d = _dayOnly(day);
    switch (slot) {
      case '9-12':
        return (startLocal: DateTime(d.year, d.month, d.day, 9), endLocal: DateTime(d.year, d.month, d.day, 12));
      case '12-15':
        return (startLocal: DateTime(d.year, d.month, d.day, 12), endLocal: DateTime(d.year, d.month, d.day, 15));
      case '15-18':
        return (startLocal: DateTime(d.year, d.month, d.day, 15), endLocal: DateTime(d.year, d.month, d.day, 18));
      case 'Full Day':
      default:
        return (startLocal: DateTime(d.year, d.month, d.day, 9), endLocal: DateTime(d.year, d.month, d.day, 18));
    }
  }

  // ----------------------------
  // RPC: can_user_book
  // ----------------------------

  /// Calls `can_user_book(p_start, p_end)` and normalizes return into a map.
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
    if (res is List && res.isNotEmpty && res.first is Map) return Map<String, dynamic>.from(res.first as Map);
    if (res is bool) return {'allowed': res};
    return {'allowed': false, 'reason': 'Please try again.'};
  }

  Future<Map<String, dynamic>> _canUserBookSelectedSlot() async {
    final slot = selectedTimeSlot;
    if (slot == null) return {'allowed': false, 'reason': 'Please select a time slot first.'};

    final range = _slotToRangeLocal(selectedDate, slot);
    return _canUserBookForRange(startLocal: range.startLocal, endLocal: range.endLocal);
  }

  Future<void> _refreshEntitlementForSelectedDate() async {
    final range = _slotToRangeLocal(selectedDate, 'Full Day');

    try {
      final res = await _canUserBookForRange(startLocal: range.startLocal, endLocal: range.endLocal);

      final entitlement = (res['entitlement'] ?? '').toString().trim().toLowerCase();
      final passOnly = entitlement == 'pass';

      if (!mounted) return;

      setState(() {
        _entitlement = entitlement.isEmpty ? null : entitlement;
        _passOnlyFullDay = passOnly;
      });

      if (passOnly) {
        if (selectedTimeSlot != 'Full Day') {
          setState(() => selectedTimeSlot = 'Full Day');
          await _loadSlotCounts();
        }
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _entitlement = null;
        _passOnlyFullDay = false;
      });
    }
  }

  void _showNeedsEntitlementSnack(String? reason) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(reason ?? 'To book a space, please activate a membership or buy a pass.'),
        backgroundColor: Colors.red,
        action: SnackBarAction(
          label: 'Memberships',
          textColor: Colors.white,
          onPressed: () {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MembershipScreen()));
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
        content: Text('You already have a booking in this time slot. Please choose another slot.'),
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
          .select('id,name,workspace_type,capacity,is_bookable,workspace_description')
          .eq('is_bookable', true)
          .order('id', ascending: true);

      final list = (rows as List).map((r) => _Workspace.fromJson(r as Map<String, dynamic>)).toList();

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

    final totalCapacityPerDay =
    _workspaces.fold<int>(0, (sum, w) => sum + (w.capacity <= 0 ? 1 : w.capacity)).clamp(1, 999999);

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
      for (var day = monthStart; day.isBefore(nextMonthStart); day = day.add(const Duration(days: 1))) {
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
    } catch (_) {
      // ignore
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
        final type = (map['meeting_booking_type'] ?? '').toString().trim().toLowerCase();

        counts[wid] = (counts[wid] ?? 0) + 1;
        if (type == 'private') privateRooms.add(wid);
      }

      if (!mounted) return;
      setState(() {
        _bookedCountByWorkspaceId = counts;
        _privateBookedMeetingRoomIds = privateRooms;
        _loadingSlotCounts = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingSlotCounts = false);
    }
  }

  // Preference filtering
  List<_Workspace> _applyPreferenceFilter(List<_Workspace> all) {
    final pref = selectedPreference;
    if (pref == null) return all;

    if (pref == 'Quiet Zone') {
      return all.where((w) => w.workspaceType == 'FOCUS_BOX' || w.workspaceType == 'MEETING_ROOM').toList();
    } else {
      return all.where((w) => w.workspaceType != 'FOCUS_BOX').toList();
    }
  }

  int _remainingForWorkspace(_Workspace w) {
    final isMeetingRoom = w.workspaceType == 'MEETING_ROOM';
    final privateBooked = isMeetingRoom && _privateBookedMeetingRoomIds.contains(w.id);
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
        return const ['Comfortable benches', 'Talk & collaborate', 'More privacy'];
      case 'SHARED_DESK':
        return const ['Big shared table', 'Community vibe', 'Fast Wi‑Fi'];
      default:
        return const ['Fast Wi‑Fi', 'Power outlet', 'Comfortable seat'];
    }
  }

  Future<bool> _canBookMeetingRoomPrivate() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return false;

      final row = await supabase.from('users').select('membership_type,membership_status').eq('id', user.id).maybeSingle();
      if (row == null) return false;

      final type = (row['membership_type'] ?? '').toString().trim().toLowerCase();
      final status = (row['membership_status'] ?? '').toString().trim().toLowerCase();

      if (status != 'active') return false;
      return type == 'full' || type == 'regular';
    } catch (_) {
      return false;
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
        title: const Text('Booking confirmed!', style: TextStyle(fontFamily: 'SweetAndSalty')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(workspaceName, style: const TextStyle(fontFamily: 'CharlevoixPro', fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(date, style: const TextStyle(fontFamily: 'CharlevoixPro')),
            Text(time, style: const TextStyle(fontFamily: 'CharlevoixPro')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK', style: TextStyle(fontFamily: 'CharlevoixPro')),
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

    try {
      final can = await _canUserBookSelectedSlot();
      if (!mounted) return;

      if (can['allowed'] != true) {
        _showNeedsEntitlementSnack(can['reason']?.toString());
        return;
      }
    } catch (_) {}

    try {
      final hasOverlap = await _userHasOverlapForSlot(day: selectedDate, slot: selectedTimeSlot!);
      if (!mounted) return;
      if (hasOverlap) {
        _showOverlapSnack();
        return;
      }
    } catch (_) {}

    final available = candidates.where((w) {
      if (w.workspaceType == 'MEETING_ROOM' && _privateBookedMeetingRoomIds.contains(w.id)) return false;
      return _remainingForWorkspace(w) > 0;
    }).toList();

    if (available.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No seats left in this category for the selected slot.'), backgroundColor: Colors.red),
      );
      return;
    }

    final chosen = available.first;
    final range = _slotToRangeLocal(selectedDate, selectedTimeSlot!);

    MeetingBookingType? meetingType;
    if (chosen.workspaceType == 'MEETING_ROOM') {
      final selection = await showModalBottomSheet<MeetingBookingType>(
        context: context,
        builder: (ctx) => MeetingRoomSelectionSheet(currentUserMembership: UserMembership.regular),
      );
      if (selection == null) return;
      meetingType = selection;

      if (meetingType == MeetingBookingType.private) {
        final allowed = await _canBookMeetingRoomPrivate();
        if (!allowed) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Private meeting room booking is only available for active Full or Regular members.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }
    }

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddExtrasBottomSheet(
        workspaceName: '${chosen.name} ${_emojiForWorkspaceType(chosen.workspaceType)}',
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
        const SnackBar(content: Text('Please log in again.'), backgroundColor: Colors.red),
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
        payload['meeting_booking_type'] = meetingType == MeetingBookingType.private ? 'private' : 'shared';
      }

      await supabase.from('bookings').insert(payload).select('id').single();

      await _loadSlotCounts();
      await _loadMonthOccupancy(selectedDate);

      await _showBookingConfirmedDialog(
        workspaceName: chosen.name,
        startLocal: range.startLocal,
        endLocal: range.endLocal,
      );
    } catch (e) {
      if (!mounted) return;

      final friendly = _looksLikeOverlapException(e)
          ? 'You already have a booking in this time slot. Please choose another slot.'
          : 'Booking failed. Please try again.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendly), backgroundColor: Colors.red),
      );
    }
  }

  // ----------------------------
  // UI helpers
  // ----------------------------

  List<String> get _visibleTimeSlots => _passOnlyFullDay ? const ['Full Day'] : _allTimeSlots;

  @override
  Widget build(BuildContext context) {
    final filtered = _applyPreferenceFilter(_workspaces);

    final Map<String, List<_Workspace>> byType = {};
    for (final w in filtered) {
      byType.putIfAbsent(w.workspaceType, () => []).add(w);
    }

    final types = byType.keys.toList()..sort((a, b) => _categoryLabel(a).compareTo(_categoryLabel(b)));

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
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'Find your perfect spot!',
                style: TextStyle(fontFamily: 'SweetAndSalty', fontSize: 28, color: AppTheme.darkText),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 6),
            const Center(
              child: Text(
                'Book a workspace that fits your needs',
                style: TextStyle(fontFamily: 'CharlevoixPro', fontSize: 14, color: AppTheme.secondaryText),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "Choose your date",
              style: TextStyle(fontFamily: 'CharlevoixPro', fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.darkText),
            ),
            const SizedBox(height: 16),
            CalendarWidget(
              selectedDate: selectedDate,
              onDateSelected: (date) async {
                setState(() => selectedDate = date);
                await _loadMonthOccupancy(date);

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
              style: TextStyle(fontFamily: 'CharlevoixPro', fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.darkText),
            ),
            const SizedBox(height: 10),
            if (_passOnlyFullDay)
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Text(
                  'Passes can be used for Full Day bookings only.',
                  style: TextStyle(fontFamily: 'CharlevoixPro', fontSize: 13, color: AppTheme.secondaryText),
                ),
              ),
            _buildFilterChips(_visibleTimeSlots, selectedTimeSlot, (val) async {
              if (_passOnlyFullDay && val != null && val != 'Full Day') return;

              setState(() => selectedTimeSlot = val);
              if (val != null) await _loadSlotCounts();
            }),
            const SizedBox(height: 40),
            const Text(
              "Preferences",
              style: TextStyle(fontFamily: 'CharlevoixPro', fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.darkText),
            ),
            const SizedBox(height: 16),
            _buildFilterChips(preferences, selectedPreference, (val) {
              setState(() => selectedPreference = val);
              if (selectedTimeSlot != null) _loadSlotCounts();
            }),
            const SizedBox(height: 40),
            const Text(
              "Available Workspaces",
              style: TextStyle(fontFamily: 'CharlevoixPro', fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.darkText),
            ),
            const SizedBox(height: 16),
            if (selectedTimeSlot == null)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  "Please select a time slot to see available categories.",
                  style: TextStyle(fontFamily: 'CharlevoixPro', fontSize: 14, color: AppTheme.secondaryText),
                ),
              )
            else if (_loadingWorkspaces)
              const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
            else if (_workspacesError != null)
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text(_workspacesError!, style: const TextStyle(fontFamily: 'CharlevoixPro', color: Colors.red)),
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
                          style: TextStyle(fontFamily: 'CharlevoixPro', fontSize: 14, color: AppTheme.secondaryText),
                        ),
                      );
                    }

                    return Column(
                      children: visibleTypes.map((type) {
                        final seats = byType[type] ?? const [];
                        final seatsLeft = _loadingSlotCounts ? null : _remainingForCategory(seats);
                        final benefits = _benefitsForWorkspaceType(type).take(3).toList();

                        final disabled = seatsLeft != null && seatsLeft <= 0;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.black.withOpacity(0.08)),
                              boxShadow: [
                                BoxShadow(
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                  color: Colors.black.withOpacity(0.06),
                                )
                              ],
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                                          : (seatsLeft == 1 ? '1 seat left' : '$seatsLeft seats left'),
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
                                        padding: const EdgeInsets.only(bottom: 4),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('• ',
                                                style: TextStyle(fontFamily: 'CharlevoixPro', color: AppTheme.darkText)),
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
                                          onPressed: disabled ? null : () => _quickSelectAndBook(seats),
                                          style: ButtonStyle(
                                            backgroundColor: WidgetStateProperty.all(_selectedChipPink),
                                            shape: WidgetStateProperty.all(
                                              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
                                            if (selectedTimeSlot == null) return;

                                            try {
                                              final can = await _canUserBookSelectedSlot();
                                              if (!mounted) return;

                                              if (can['allowed'] != true) {
                                                _showNeedsEntitlementSnack(can['reason']?.toString());
                                                return;
                                              }
                                            } catch (_) {}

                                            try {
                                              final hasOverlap = await _userHasOverlapForSlot(
                                                day: selectedDate,
                                                slot: selectedTimeSlot!,
                                              );
                                              if (!mounted) return;

                                              if (hasOverlap) {
                                                _showOverlapSnack();
                                                return;
                                              }
                                            } catch (_) {}

                                            await Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) => WorkspaceMapScreen(
                                                  selectedDate: selectedDate,
                                                  selectedTimeSlot: selectedTimeSlot!,
                                                  selectedPreference: selectedPreference,
                                                  selectedCategoryType: type,
                                                ),
                                              ),
                                            );

                                            if (selectedTimeSlot != null) {
                                              await _loadSlotCounts();
                                              await _loadMonthOccupancy(selectedDate);
                                            }
                                          },
                                          style: OutlinedButton.styleFrom(
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                            side: BorderSide(color: Colors.black.withOpacity(0.18)),
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

  Widget _buildFilterChips(List<String> items, String? selectedItem, Function(String?) onSelected) {
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
              border: Border.all(color: isSelected ? _selectedChipPink : Colors.black.withOpacity(0.08)),
              boxShadow: [BoxShadow(blurRadius: 8, offset: const Offset(0, 3), color: Colors.black.withOpacity(0.06))],
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
