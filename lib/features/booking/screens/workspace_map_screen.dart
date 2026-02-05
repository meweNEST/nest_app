import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../models/booking_models.dart';
import '../widgets/add_extras_bottom_sheet.dart';
import '../widgets/meeting_room_selection_sheet.dart';

class WorkspaceMapScreen extends StatefulWidget {
  final DateTime selectedDate;
  final String selectedTimeSlot;
  final String? selectedPreference;

  /// If set, only this category is selectable + highlighted.
  final String? selectedCategoryType;

  const WorkspaceMapScreen({
    super.key,
    required this.selectedDate,
    required this.selectedTimeSlot,
    required this.selectedPreference,
    this.selectedCategoryType,
  });

  @override
  State<WorkspaceMapScreen> createState() => _WorkspaceMapScreenState();
}

class _WorkspaceMapScreenState extends State<WorkspaceMapScreen> {
  final supabase = Supabase.instance.client;

  static const Color _selectedChipPink = Color(0xFFF87CC8);

  /// Must be the SAME dotted blueprint used to extract coordinates.
  static const String _blueprintAssetPath = 'assets/images/nest_blueprint.png';

  bool _loading = true;
  String? _error;

  List<_Workspace> _workspaces = [];

  /// workspace_id -> number of bookings that overlap the selected slot
  Map<int, int> _bookedCountByWorkspaceId = {};

  /// meeting rooms that have at least one PRIVATE booking in the selected slot
  Set<int> _privateBookedMeetingRoomIds = {};

  /// workspace_id -> normalized position (0..1)
  Map<int, Offset> _posNormByWorkspaceId = {};

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final blocked = await _guardBeforeShowingMap();
      if (blocked) return;
      await _loadAll();
    });
  }

  // ----------------------------
  // Time range helpers
  // ----------------------------

  DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

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
  // Guards: entitlement + overlap
  // ----------------------------

  Future<Map<String, dynamic>> _canUserBookCurrentSlot() async {
    final range = _slotToRangeLocal(widget.selectedDate, widget.selectedTimeSlot);
    final startUtc = range.startLocal.toUtc().toIso8601String();
    final endUtc = range.endLocal.toUtc().toIso8601String();

    final res = await supabase.rpc('can_user_book', params: {
      'p_start': startUtc,
      'p_end': endUtc,
    });

    if (res is Map) return Map<String, dynamic>.from(res);
    if (res is List && res.isNotEmpty && res.first is Map) return Map<String, dynamic>.from(res.first as Map);
    return {'allowed': false, 'reason': 'Please try again.'};
  }

  Future<bool> _userHasOverlapForCurrentSlot() async {
    final user = supabase.auth.currentUser;
    if (user == null) return false;

    final range = _slotToRangeLocal(widget.selectedDate, widget.selectedTimeSlot);
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

  Future<void> _showBlockedDialog({
    required String title,
    required String message,
  }) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontFamily: 'SweetAndSalty')),
        content: Text(message, style: const TextStyle(fontFamily: 'CharlevoixPro')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK', style: TextStyle(fontFamily: 'CharlevoixPro')),
          )
        ],
      ),
    );
  }

  /// Returns true if blocked and we navigated away.
  Future<bool> _guardBeforeShowingMap() async {
    // 1) entitlement / rules / pass-full-day enforcement
    try {
      final can = await _canUserBookCurrentSlot();
      final allowed = can['allowed'] == true;
      if (!allowed) {
        final reason = (can['reason'] ?? 'Booking not available.').toString();
        await _showBlockedDialog(title: 'Booking not available', message: reason);
        if (!mounted) return true;
        Navigator.of(context).pop();
        return true;
      }
    } catch (_) {
      // If RPC fails, don’t block—DB constraints/RLS still protect inserts.
    }

    // 2) overlap check (nice UX)
    try {
      final hasOverlap = await _userHasOverlapForCurrentSlot();
      if (hasOverlap) {
        await _showBlockedDialog(
          title: 'Already booked',
          message: 'You already have a booking in this time slot. Please choose another slot.',
        );
        if (!mounted) return true;
        Navigator.of(context).pop();
        return true;
      }
    } catch (_) {}

    return false;
  }

  // ----------------------------
  // Loading
  // ----------------------------

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final rows = await supabase
          .from('workspaces')
          .select('id,name,workspace_type,capacity,is_bookable,workspace_description')
          .eq('is_bookable', true)
          .order('id', ascending: true);

      _workspaces = (rows as List).map((r) => _Workspace.fromJson(r as Map<String, dynamic>)).toList();

      await _loadPositions();
      await _loadSlotCounts();

      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadPositions() async {
    final rows = await supabase.from('workspace_map_positions').select('workspace_id,x,y');

    final Map<int, Offset> m = {};
    for (final r in (rows as List)) {
      final map = r as Map<String, dynamic>;
      final id = (map['workspace_id'] as num).toInt();
      final x = (map['x'] as num).toDouble();
      final y = (map['y'] as num).toDouble();
      m[id] = Offset(x, y);
    }

    _posNormByWorkspaceId = m;
  }

  Future<void> _loadSlotCounts() async {
    final range = _slotToRangeLocal(widget.selectedDate, widget.selectedTimeSlot);
    final startUtc = range.startLocal.toUtc().toIso8601String();
    final endUtc = range.endLocal.toUtc().toIso8601String();

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

    _bookedCountByWorkspaceId = counts;
    _privateBookedMeetingRoomIds = privateRooms;
  }

  // Preference filtering
  List<_Workspace> _applyPreferenceFilter(List<_Workspace> all) {
    final pref = widget.selectedPreference;
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

  Color _colorForWorkspace(_Workspace w) {
    final name = w.name.toLowerCase();
    if (w.workspaceType == 'SHARED_DESK') return const Color(0xFFB2E5D1);
    if (w.workspaceType == 'STANDING_DESK') return const Color(0xFFFFBD59);
    if (w.workspaceType == 'SPIELFELDRAND_SEAT') return const Color(0xFFFFDE59);
    if (w.workspaceType == 'FOCUS_BOX') return const Color(0xFFFF5757);
    if (w.workspaceType == 'MEETING_ROOM') {
      if (name.contains('1')) return const Color(0xFFF87CC8);
      if (name.contains('2')) return const Color(0xFFF8A6D8);
      return _selectedChipPink;
    }
    return _selectedChipPink;
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

      final row = await supabase
          .from('users')
          .select('membership_type,membership_status')
          .eq('id', user.id)
          .maybeSingle();

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

  String _friendlyBookingError(Object e) {
    final s = e.toString().toLowerCase();

    if (s.contains('23p01') || s.contains('no_overlapping_bookings_per_user') || s.contains('exclusion constraint')) {
      return 'You already have a booking in this time slot. Please choose another slot.';
    }
    if (s.contains('passes can only be used for full day')) {
      return 'Passes can only be used for Full Day bookings. Please select Full Day.';
    }
    if (s.contains('house rules')) {
      return 'Please accept the house rules to book.';
    }
    if (s.contains('no valid pass') || s.contains('no pass') || s.contains('credits')) {
      return 'No valid pass credits available. Please buy a pass or activate a membership.';
    }
    return 'Booking failed. Please try again.';
  }

  Future<void> _handleSeatTap(_Workspace workspace) async {
    // Lock selection to chosen category if set
    if (widget.selectedCategoryType != null && workspace.workspaceType != widget.selectedCategoryType) return;

    // Re-check entitlement & overlap (race-safe)
    try {
      final can = await _canUserBookCurrentSlot();
      if (!mounted) return;
      if (can['allowed'] != true) {
        final reason = (can['reason'] ?? 'Booking not available.').toString();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(reason), backgroundColor: Colors.red));
        return;
      }
    } catch (_) {}

    try {
      final hasOverlap = await _userHasOverlapForCurrentSlot();
      if (!mounted) return;
      if (hasOverlap) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You already have a booking in this time slot. Please choose another slot.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    } catch (_) {}

    final isMeetingRoom = workspace.workspaceType == 'MEETING_ROOM';
    final privateBooked = isMeetingRoom && _privateBookedMeetingRoomIds.contains(workspace.id);

    final remaining = _remainingForWorkspace(workspace);
    final capacity = workspace.capacity <= 0 ? 1 : workspace.capacity;

    // 1-seat desks: if booked, should not be tappable anyway
    if (!isMeetingRoom && capacity == 1 && remaining <= 0) return;

    // meeting room private: blocked entirely
    if (isMeetingRoom && privateBooked) return;

    final range = _slotToRangeLocal(widget.selectedDate, widget.selectedTimeSlot);

    MeetingBookingType? meetingType;
    if (isMeetingRoom) {
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
        workspaceName: workspace.name,
        workspaceSubline: workspace.description ?? '',
        workspaceBenefits: _benefitsForWorkspaceType(workspace.workspaceType),
        startLocal: range.startLocal,
        endLocal: range.endLocal,
      ),
    );

    if (confirmed != true) return;

    final user = supabase.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in again.'), backgroundColor: Colors.red),
      );
      return;
    }

    final startUtc = range.startLocal.toUtc().toIso8601String();
    final endUtc = range.endLocal.toUtc().toIso8601String();

    try {
      final payload = <String, dynamic>{
        'workspace_id': workspace.id,
        'user_id': user.id,
        'start_time': startUtc,
        'end_time': endUtc,
      };

      if (isMeetingRoom && meetingType != null) {
        payload['meeting_booking_type'] = meetingType == MeetingBookingType.private ? 'private' : 'shared';
      }

      await supabase.from('bookings').insert(payload).select('id').single();

      await _loadSlotCounts();
      if (!mounted) return;
      setState(() {});

      await _showBookingConfirmedDialog(
        workspaceName: workspace.name,
        startLocal: range.startLocal,
        endLocal: range.endLocal,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyBookingError(e)), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final range = _slotToRangeLocal(widget.selectedDate, widget.selectedTimeSlot);
    final localizations = MaterialLocalizations.of(context);

    final displayDate = localizations.formatFullDate(range.startLocal);
    final displayTime =
        '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(range.startLocal))} - '
        '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(range.endLocal))}';

    final seats = _applyPreferenceFilter(_workspaces);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Map view', style: TextStyle(fontFamily: 'CharlevoixPro', color: AppTheme.darkText)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.darkText),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_error != null)
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(_error!, style: const TextStyle(color: Colors.red)),
        ),
      )
          : Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            displayDate,
            style: const TextStyle(
              fontFamily: 'CharlevoixPro',
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            displayTime,
            style: const TextStyle(
              fontFamily: 'CharlevoixPro',
              fontSize: 14,
              color: AppTheme.secondaryText,
            ),
          ),
          if (widget.selectedCategoryType != null) ...[
            const SizedBox(height: 4),
            Text(
              'Category: ${_categoryLabel(widget.selectedCategoryType!)}',
              style: const TextStyle(
                fontFamily: 'CharlevoixPro',
                fontSize: 13,
                color: AppTheme.secondaryText,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final mapSize = Size(
                  constraints.maxWidth,
                  min(constraints.maxHeight, constraints.maxWidth * 0.72),
                );

                return Center(
                  child: InteractiveViewer(
                    minScale: 0.9,
                    maxScale: 3.0,
                    child: SizedBox(
                      width: mapSize.width,
                      height: mapSize.height,
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.asset(
                              _blueprintAssetPath,
                              width: mapSize.width,
                              height: mapSize.height,
                              fit: BoxFit.contain,
                            ),
                          ),
                          ...seats.map((w) {
                            final norm = _posNormByWorkspaceId[w.id];
                            if (norm == null) return const SizedBox.shrink();

                            final p = Offset(norm.dx * mapSize.width, norm.dy * mapSize.height);

                            final isMeetingRoom = w.workspaceType == 'MEETING_ROOM';
                            final privateBooked = isMeetingRoom && _privateBookedMeetingRoomIds.contains(w.id);

                            final remaining = _remainingForWorkspace(w);
                            final capacity = w.capacity <= 0 ? 1 : w.capacity;

                            // 1-seat desks: hide when booked
                            if (!isMeetingRoom && capacity == 1 && remaining <= 0) {
                              return const SizedBox.shrink();
                            }

                            // Meeting rooms: hide when fully booked by capacity; keep private-booked visible but disabled
                            if (isMeetingRoom && remaining <= 0 && !privateBooked) {
                              return const SizedBox.shrink();
                            }

                            final locked = widget.selectedCategoryType != null;
                            final isActiveCategory = !locked || w.workspaceType == widget.selectedCategoryType;
                            final opacity = isActiveCategory ? 1.0 : 0.22;

                            const markerSize = 22.0;
                            final borderColor = _colorForWorkspace(w);

                            return Positioned(
                              left: p.dx - markerSize / 2,
                              top: p.dy - markerSize / 2,
                              child: Opacity(
                                opacity: opacity,
                                child: MouseRegion(
                                  cursor: (isActiveCategory && !privateBooked)
                                      ? SystemMouseCursors.click
                                      : SystemMouseCursors.basic,
                                  child: Tooltip(
                                    message: w.name,
                                    child: GestureDetector(
                                      onTap: (!isActiveCategory || privateBooked) ? null : () => _handleSeatTap(w),
                                      child: Container(
                                        width: markerSize,
                                        height: markerSize,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white.withOpacity(0.92),
                                          border: Border.all(color: borderColor, width: 2),
                                          boxShadow: [
                                            BoxShadow(
                                              blurRadius: 8,
                                              offset: const Offset(0, 3),
                                              color: Colors.black.withOpacity(0.10),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            "Tip: pinch to zoom. Hover (or long press) a dot to see the seat name.",
            style: TextStyle(
              fontFamily: 'CharlevoixPro',
              fontSize: 13,
              color: AppTheme.secondaryText,
            ),
          ),
        ]),
      ),
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
