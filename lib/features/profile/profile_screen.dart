import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../widgets/nest_app_bar.dart';
import '../../widgets/nest_button.dart';
import '../membership/membership_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final supabase = Supabase.instance.client;

  bool _loading = true;
  String? _error;

  Map<String, dynamic>? _me; // public.users row
  List<Map<String, dynamic>> _children = [];

  Map<String, String> _workspaceNameById = {};

  Map<String, dynamic>? _upcomingBooking; // first CONFIRMED future booking
  List<Map<String, dynamic>> _futureBookings = [];
  List<Map<String, dynamic>> _pastBookings = [];

  // UI prefs (stored locally)
  bool _notificationsEnabled = true;
  bool _commMarketing = false;
  bool _commEmail = true;
  bool _commPhone = false;
  bool _commTracking = false;

  // stored in DB
  String _language = 'de';

  // Button + toggle colors
  static const Color _profileActionGreen = Color(0xFFB2E5D1);
  static const Color _profileActionGreenHover = Color(0xFF9FDAC4);

  static const Color _toggleActiveColor = Color(0xFFFFDE59);
  static final Color _toggleActiveTrackColor =
      const Color(0xFFFFDE59).withValues(alpha: 0.45);

  // Support / feedback
  static const String _nestEmail = 'membership@nest-hamburg.de';
  static const String _nestPhone = '+49 40 1234 5678';

  // Children age group constraint in DB is still ('small','big') — we only change labels shown to the user
  static const List<_AgeGroupItem> _ageGroups = <_AgeGroupItem>[
    _AgeGroupItem(value: 'small', label: 'Babies (0–2)'),
    _AgeGroupItem(value: 'big', label: 'Toddlers (3–5)'),
  ];

  // shared_preferences keys
  static const _prefsKeyNotifications = 'profile.notifications_enabled';
  static const _prefsKeyCommMarketing = 'profile.comm_marketing';
  static const _prefsKeyCommEmail = 'profile.comm_email';
  static const _prefsKeyCommPhone = 'profile.comm_phone';
  static const _prefsKeyCommTracking = 'profile.comm_tracking';

  @override
  void initState() {
    super.initState();
    _loadLocalPrefs();
    _loadAll();
  }

  // ----------------------------
  // Local prefs
  // ----------------------------
  Future<void> _loadLocalPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;

      setState(() {
        _notificationsEnabled = prefs.getBool(_prefsKeyNotifications) ?? true;
        _commMarketing = prefs.getBool(_prefsKeyCommMarketing) ?? false;
        _commEmail = prefs.getBool(_prefsKeyCommEmail) ?? true;
        _commPhone = prefs.getBool(_prefsKeyCommPhone) ?? false;
        _commTracking = prefs.getBool(_prefsKeyCommTracking) ?? false;
      });
    } catch (_) {
      // ignore
    }
  }

  Future<void> _setBoolPref(String key, bool v) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, v);
    } catch (_) {
      // ignore
    }
  }

  // ----------------------------
  // Logout
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
  // Loading
  // ----------------------------
  Future<void> _loadAll() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      setState(() {
        _loading = false;
        _error = null;
        _me = null;
        _children = [];
        _workspaceNameById = {};
        _upcomingBooking = null;
        _futureBookings = [];
        _pastBookings = [];
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final me = await supabase
          .from('users')
          .select(
            'id,email,full_name,nickname,gender,phone,language,'
            'membership_type,membership_status,membership_start_date,membership_end_date,'
            'house_rules_accepted,house_rules_accepted_at,created_at,updated_at',
          )
          .eq('id', user.id)
          .maybeSingle();

      final kidsRows = await supabase
          .from('children')
          .select('*')
          .eq('user_id', user.id)
          .order('created_at');

      final nowUtc = DateTime.now().toUtc().toIso8601String();

      final futureRows = await supabase
          .from('bookings')
          .select(
              'id,workspace_id,start_time,end_time,status,meeting_booking_type,access_pass_purchase_id')
          .eq('user_id', user.id)
          .gt('end_time', nowUtc)
          .order('start_time', ascending: true)
          .limit(60);

      final pastRows = await supabase
          .from('bookings')
          .select(
              'id,workspace_id,start_time,end_time,status,meeting_booking_type,access_pass_purchase_id')
          .eq('user_id', user.id)
          .lte('end_time', nowUtc)
          .order('start_time', ascending: false)
          .limit(80);

      final future = List<Map<String, dynamic>>.from(futureRows as List);
      final past = List<Map<String, dynamic>>.from(pastRows as List);
      final kids = List<Map<String, dynamic>>.from(kidsRows as List);

      // pick first CONFIRMED future booking (ignore CANCELLED/etc)
      Map<String, dynamic>? upcoming;
      for (final b in future) {
        if (_isConfirmed(b['status'])) {
          upcoming = b;
          break;
        }
      }

      final workspaceIds = <int>{
        ...future.map((b) => _asInt(b['workspace_id'])),
        ...past.map((b) => _asInt(b['workspace_id'])),
      }..removeWhere((id) => id <= 0);

      Map<String, String> nameMap = {};
      if (workspaceIds.isNotEmpty) {
        final wsRows = await supabase
            .from('workspaces')
            .select('id,name')
            .inFilter('id', workspaceIds.toList());
        final ws = List<Map<String, dynamic>>.from(wsRows as List);
        nameMap = {
          for (final w in ws) '${w['id']}': (w['name'] ?? '').toString()
        };
      }

      if (!mounted) return;
      setState(() {
        _me = me;
        _children = kids;
        _workspaceNameById = nameMap;

        _futureBookings = future;
        _pastBookings = past;
        _upcomingBooking = upcoming;

        final lang = (_me?['language'] ?? '').toString().trim().toLowerCase();
        _language = (lang == 'en' || lang == 'de') ? lang : 'de';

        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // ----------------------------
  // Edit profile (now includes nickname + gender)
  // ----------------------------
  Future<void> _showEditProfileSheet() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final fullNameCtrl =
        TextEditingController(text: (_me?['full_name'] ?? '').toString());
    final nicknameCtrl =
        TextEditingController(text: (_me?['nickname'] ?? '').toString());
    final phoneCtrl =
        TextEditingController(text: (_me?['phone'] ?? '').toString());

    String? gender = (_me?['gender'] ?? '').toString().trim();
    if (gender.isEmpty) gender = null;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetCtx) {
        final bottomInset = MediaQuery.of(sheetCtx).viewInsets.bottom;

        return SafeArea(
          top: false,
          child: StatefulBuilder(
            builder: (ctx, setSheetState) {
              return Padding(
                padding: EdgeInsets.fromLTRB(20, 18, 20, 18 + bottomInset),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Edit profile',
                        style: TextStyle(
                          fontFamily: 'SweetAndSalty',
                          fontSize: 26,
                          color: AppTheme.darkText,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _textField(label: 'Full name', controller: fullNameCtrl),
                      const SizedBox(height: 12),
                      _textField(
                          label: 'Nickname (optional)',
                          controller: nicknameCtrl),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String?>(
                        initialValue: gender,
                        isDense: true,
                        decoration: InputDecoration(
                          labelText: 'Gender (optional)',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                        items: const [
                          DropdownMenuItem(value: null, child: Text('—')),
                          DropdownMenuItem(
                              value: 'female', child: Text('Female')),
                          DropdownMenuItem(value: 'male', child: Text('Male')),
                          DropdownMenuItem(
                              value: 'diverse', child: Text('Diverse')),
                          DropdownMenuItem(
                              value: 'prefer_not_to_say',
                              child: Text('Prefer not to say')),
                        ],
                        onChanged: (v) => setSheetState(() => gender = v),
                      ),
                      const SizedBox(height: 12),
                      _textField(
                          label: 'Phone (optional)',
                          controller: phoneCtrl,
                          keyboardType: TextInputType.phone),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(sheetCtx).pop(),
                              style: _outlinedPillStyle(),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Text(
                                  'Cancel',
                                  style: TextStyle(
                                    fontFamily: 'CharlevoixPro',
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.darkText,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            // Save uses standard pink button (default NestPrimaryButton)
                            child: NestPrimaryButton(
                              text: 'Save',
                              onPressed: () async {
                                final full = fullNameCtrl.text.trim();
                                final nick = nicknameCtrl.text.trim();
                                final phone = phoneCtrl.text.trim();

                                try {
                                  await supabase.from('users').update({
                                    'full_name': full.isEmpty ? null : full,
                                    'nickname': nick.isEmpty ? null : nick,
                                    'gender': gender,
                                    'phone': phone.isEmpty ? null : phone,
                                  }).eq('id', user.id);

                                  if (!mounted) return;
                                  if (sheetCtx.mounted) {
                                    Navigator.of(sheetCtx).pop();
                                  }
                                  await _loadAll();
                                  if (!mounted) return;
                                  if (!context.mounted) return;

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('Profile saved.'),
                                        backgroundColor: Colors.green),
                                  );
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text('Could not save: $e'),
                                        backgroundColor: Colors.red),
                                  );
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );

    fullNameCtrl.dispose();
    nicknameCtrl.dispose();
    phoneCtrl.dispose();
  }

  // ----------------------------
  // Change password
  // ----------------------------
  Future<void> _showChangePasswordSheet() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final pass1 = TextEditingController();
    final pass2 = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetCtx) {
        final bottomInset = MediaQuery.of(sheetCtx).viewInsets.bottom;

        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 18 + bottomInset),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Change password',
                    style: TextStyle(
                        fontFamily: 'SweetAndSalty',
                        fontSize: 26,
                        color: AppTheme.darkText),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: pass1,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'New password',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: pass2,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Confirm new password',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(sheetCtx).pop(),
                          style: _outlinedPillStyle(),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                  fontFamily: 'CharlevoixPro',
                                  fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: NestPrimaryButton(
                          text: 'Update',
                          backgroundColor: _profileActionGreen,
                          hoverColor: _profileActionGreenHover,
                          textColor: AppTheme.darkText,
                          onPressed: () async {
                            final p1 = pass1.text.trim();
                            final p2 = pass2.text.trim();

                            if (p1.length < 8) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Password must be at least 8 characters.'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }
                            if (p1 != p2) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Passwords do not match.'),
                                    backgroundColor: Colors.red),
                              );
                              return;
                            }

                            try {
                              await supabase.auth
                                  .updateUser(UserAttributes(password: p1));
                              if (!mounted) return;
                              if (!sheetCtx.mounted) return;
                              Navigator.of(sheetCtx).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Password updated.'),
                                    backgroundColor: Colors.green),
                              );
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content:
                                        Text('Could not update password: $e'),
                                    backgroundColor: Colors.red),
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    pass1.dispose();
    pass2.dispose();
  }

  // ----------------------------
  // Membership management (bottom sheet)
  // ----------------------------
  Future<void> _showManageMembershipSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Manage membership',
                  style: TextStyle(
                    fontFamily: 'SweetAndSalty',
                    fontSize: 26,
                    color: AppTheme.darkText,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: NestPrimaryButton(
                    text: 'Change membership',
                    backgroundColor: _profileActionGreen,
                    hoverColor: _profileActionGreenHover,
                    textColor: AppTheme.darkText,
                    onPressed: () {
                      Navigator.of(sheetCtx).pop();
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const MembershipScreen()));
                    },
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: NestPrimaryButton(
                    text: 'Payment methods',
                    backgroundColor: _profileActionGreen,
                    hoverColor: _profileActionGreenHover,
                    textColor: AppTheme.darkText,
                    onPressed: () async {
                      Navigator.of(sheetCtx).pop();
                      await _openPaymentMethods();
                    },
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () async {
                      Navigator.of(sheetCtx).pop();
                      await _cancelMembership();
                    },
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(50)),
                      side:
                          BorderSide(color: Colors.red.withValues(alpha: 0.35)),
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 24),
                    ),
                    child: const Text(
                      'Cancel membership',
                      style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontWeight: FontWeight.w600,
                          color: Colors.red),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: 220,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(sheetCtx).pop(),
                    style: _outlinedPillStyle(),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Close',
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
        );
      },
    );
  }

  Future<void> _openPaymentMethods() async {
    // Requires backend (Stripe customer portal). We try an RPC and fall back to email.
    try {
      final res =
          await supabase.rpc('create_billing_portal_session', params: {});
      final url = (res is Map && res['url'] != null)
          ? res['url'].toString()
          : res?.toString();

      if (url != null && url.startsWith('http')) {
        await _launchUri(Uri.parse(url));
        return;
      }
      throw 'No portal URL returned.';
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment portal not configured yet. Contact support.'),
          backgroundColor: Colors.black87,
        ),
      );
      await _launchUri(_mailtoUri(
        _nestEmail,
        subject: 'Payment methods',
        body: 'Hi Nest team,\n\nPlease help me update my payment method.\n',
      ));
    }
  }

  Future<void> _cancelMembership() async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Cancel membership?',
                style: TextStyle(fontFamily: 'SweetAndSalty')),
            content: const Text('Do you want to request cancellation?',
                style: TextStyle(fontFamily: 'CharlevoixPro')),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Keep',
                    style: TextStyle(fontFamily: 'CharlevoixPro')),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Cancel',
                    style: TextStyle(
                        fontFamily: 'CharlevoixPro', color: Colors.red)),
              ),
            ],
          ),
        ) ??
        false;

    if (!ok) return;

    try {
      await supabase.rpc('cancel_membership', params: {});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Cancellation requested.'),
            backgroundColor: Colors.green),
      );
      await _loadAll();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cancellation not configured yet. Contact support.'),
          backgroundColor: Colors.black87,
        ),
      );
      await _launchUri(_mailtoUri(
        _nestEmail,
        subject: 'Cancel membership',
        body: 'Hi Nest team,\n\nI would like to cancel my membership.\n',
      ));
    }
  }

  // ----------------------------
  // Language toggle
  // ----------------------------
  Future<void> _setLanguage(String lang) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    setState(() => _language = lang);

    try {
      await supabase.from('users').update({'language': lang}).eq('id', user.id);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Language: ${lang == 'de' ? 'Deutsch' : 'English'}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Could not update language: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  // ----------------------------
  // Bookings
  // ----------------------------
  bool _isConfirmed(dynamic statusRaw) {
    final s = (statusRaw ?? '').toString().trim().toLowerCase();
    return s == 'confirmed' || s.isEmpty;
  }

  Future<void> _cancelBooking(Map<String, dynamic> booking) async {
    final id = booking['id'];
    if (id == null) return;

    final startLocal = _parseTimeLocal(booking['start_time']);
    final endLocal = _parseTimeLocal(booking['end_time']);
    final loc = MaterialLocalizations.of(context);

    final date = startLocal == null ? '' : loc.formatFullDate(startLocal);
    final time = (startLocal == null || endLocal == null)
        ? ''
        : '${loc.formatTimeOfDay(TimeOfDay.fromDateTime(startLocal))} – ${loc.formatTimeOfDay(TimeOfDay.fromDateTime(endLocal))}';

    final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Cancel booking?',
                style: TextStyle(fontFamily: 'SweetAndSalty')),
            content: Text(
              (date.isEmpty && time.isEmpty)
                  ? 'Are you sure you want to cancel this booking?'
                  : 'Cancel your booking on\n$date\n$time ?',
              style: const TextStyle(fontFamily: 'CharlevoixPro'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Keep',
                    style: TextStyle(fontFamily: 'CharlevoixPro')),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Cancel booking',
                    style: TextStyle(fontFamily: 'CharlevoixPro')),
              ),
            ],
          ),
        ) ??
        false;

    if (!ok) return;

    try {
      await supabase
          .from('bookings')
          .update({'status': 'CANCELLED'}).eq('id', id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Booking cancelled.'), backgroundColor: Colors.green),
      );

      await _loadAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Could not cancel booking: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  void _showBookingHistorySheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetCtx) {
        final upcoming =
            _futureBookings.where((b) => _isConfirmed(b['status'])).toList();
        final past =
            _pastBookings.where((b) => _isConfirmed(b['status'])).toList();

        Widget sectionTitle(String t) => Padding(
              padding: const EdgeInsets.only(top: 14, bottom: 8),
              child: Text(
                t,
                style: const TextStyle(
                  fontFamily: 'CharlevoixPro',
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.darkText,
                ),
              ),
            );

        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: Column(
              children: [
                const Text(
                  'All bookings',
                  style: TextStyle(
                    fontFamily: 'SweetAndSalty',
                    fontSize: 26,
                    color: AppTheme.darkText,
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView(
                    children: [
                      if (upcoming.isNotEmpty) ...[
                        sectionTitle('Upcoming'),
                        ...upcoming.map(_bookingListTile),
                      ],
                      sectionTitle('Past'),
                      if (past.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Text(
                            'No past bookings yet.',
                            style: TextStyle(
                                fontFamily: 'CharlevoixPro',
                                color: AppTheme.secondaryText),
                          ),
                        )
                      else
                        ...past.map(_bookingListTile),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: 220,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(sheetCtx).pop(),
                    style: _outlinedPillStyle(),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Close',
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
        );
      },
    );
  }

  Widget _bookingListTile(Map<String, dynamic> b) {
    final startLocal = _parseTimeLocal(b['start_time']);
    final endLocal = _parseTimeLocal(b['end_time']);
    final loc = MaterialLocalizations.of(context);

    final date = startLocal == null ? '—' : loc.formatMediumDate(startLocal);
    final time = (startLocal == null || endLocal == null)
        ? ''
        : '${loc.formatTimeOfDay(TimeOfDay.fromDateTime(startLocal))} – ${loc.formatTimeOfDay(TimeOfDay.fromDateTime(endLocal))}';

    final wid = _asInt(b['workspace_id']);
    final workspaceName = _workspaceNameById['$wid'];
    final label = (workspaceName != null && workspaceName.trim().isNotEmpty)
        ? workspaceName
        : 'Workspace #$wid';

    final isFuture = endLocal != null && endLocal.isAfter(DateTime.now());

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'CharlevoixPro',
                  fontWeight: FontWeight.w800,
                  color: AppTheme.darkText,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$date${time.isEmpty ? '' : ' • $time'}',
                style: const TextStyle(
                    fontFamily: 'CharlevoixPro', color: AppTheme.secondaryText),
              ),
            ]),
          ),
          if (isFuture)
            OutlinedButton(
              onPressed: () => _cancelBooking(b),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24)),
                side: BorderSide(color: Colors.red.withValues(alpha: 0.35)),
              ),
              child: const Text('Cancel',
                  style: TextStyle(
                      fontFamily: 'CharlevoixPro', color: Colors.red)),
            ),
        ],
      ),
    );
  }

  // ----------------------------
  // Children (add/edit/delete)
  // ----------------------------
  Future<void> _showChildEditorSheet({Map<String, dynamic>? child}) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final isEdit = child != null;

    final nameCtrl =
        TextEditingController(text: (child?['name'] ?? '').toString());
    final allergiesCtrl =
        TextEditingController(text: (child?['allergies'] ?? '').toString());
    final specialNeedsCtrl =
        TextEditingController(text: (child?['special_needs'] ?? '').toString());
    final emergencyNameCtrl = TextEditingController(
        text: (child?['emergency_contact_name'] ?? '').toString());
    final emergencyPhoneCtrl = TextEditingController(
        text: (child?['emergency_contact_phone'] ?? '').toString());

    String? ageGroup = (child?['age_group'] ?? '').toString().trim();
    if (ageGroup.isEmpty) ageGroup = null;

    DateTime? dob;
    final dobRaw = child?['date_of_birth'];
    if (dobRaw != null && dobRaw.toString().trim().isNotEmpty) {
      try {
        dob = DateTime.parse(dobRaw.toString());
      } catch (_) {}
    }

    Future<void> pickDob(
        StateSetter setModalState, BuildContext sheetCtx) async {
      final initial = dob ?? DateTime(DateTime.now().year - 3, 1, 1);
      final picked = await showDatePicker(
        context: sheetCtx,
        initialDate: initial,
        firstDate: DateTime(2005, 1, 1),
        lastDate: DateTime.now(),
      );
      if (picked == null) return;
      setModalState(() => dob = picked);
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          top: false,
          child: StatefulBuilder(
            builder: (context, setModalState) {
              final bottomInset = MediaQuery.of(sheetCtx).viewInsets.bottom;

              String dobLabel() {
                if (dob == null) return 'Select date of birth';
                final loc = MaterialLocalizations.of(sheetCtx);
                return loc.formatFullDate(dob!);
              }

              return Padding(
                padding: EdgeInsets.fromLTRB(20, 18, 20, 18 + bottomInset),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEdit ? 'Edit child' : 'Add child',
                        style: const TextStyle(
                          fontFamily: 'SweetAndSalty',
                          fontSize: 26,
                          color: AppTheme.darkText,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _textField(label: 'Name', controller: nameCtrl),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _pillAction(
                              label: dobLabel(),
                              onPressed: () => pickDob(setModalState, sheetCtx),
                              icon: Icons.cake_outlined,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _ageGroupDropdown(
                        value: ageGroup,
                        onChanged: (v) => setModalState(() => ageGroup = v),
                      ),
                      const SizedBox(height: 12),
                      _textField(
                          label: 'Allergies (optional)',
                          controller: allergiesCtrl,
                          hint: 'e.g. milk, nuts'),
                      const SizedBox(height: 12),
                      _textField(
                        label: 'Special needs (optional)',
                        controller: specialNeedsCtrl,
                        hint: 'Anything we should know',
                        maxLines: 3,
                      ),
                      const SizedBox(height: 12),
                      _textField(
                          label: 'Emergency contact name (optional)',
                          controller: emergencyNameCtrl),
                      const SizedBox(height: 12),
                      _textField(
                        label: 'Emergency contact phone (optional)',
                        controller: emergencyPhoneCtrl,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(sheetCtx).pop(),
                              style: _outlinedPillStyle(),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Text(
                                  'Cancel',
                                  style: TextStyle(
                                    fontFamily: 'CharlevoixPro',
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.darkText,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: NestPrimaryButton(
                              text: isEdit ? 'Save' : 'Add',
                              backgroundColor: _profileActionGreen,
                              hoverColor: _profileActionGreenHover,
                              textColor: AppTheme.darkText,
                              onPressed: () async {
                                final name = nameCtrl.text.trim();
                                if (name.isEmpty) {
                                  ScaffoldMessenger.of(this.context)
                                      .showSnackBar(
                                    const SnackBar(
                                        content: Text('Please enter a name.'),
                                        backgroundColor: Colors.red),
                                  );
                                  return;
                                }

                                final payload = <String, dynamic>{
                                  'user_id': user.id,
                                  'name': name,
                                  'age_group': ageGroup, // 'small'/'big'/null
                                  'allergies': allergiesCtrl.text.trim().isEmpty
                                      ? null
                                      : allergiesCtrl.text.trim(),
                                  'special_needs':
                                      specialNeedsCtrl.text.trim().isEmpty
                                          ? null
                                          : specialNeedsCtrl.text.trim(),
                                  'emergency_contact_name':
                                      emergencyNameCtrl.text.trim().isEmpty
                                          ? null
                                          : emergencyNameCtrl.text.trim(),
                                  'emergency_contact_phone':
                                      emergencyPhoneCtrl.text.trim().isEmpty
                                          ? null
                                          : emergencyPhoneCtrl.text.trim(),
                                  'date_of_birth':
                                      dob == null ? null : _dateOnlyIso(dob!),
                                };

                                try {
                                  if (isEdit) {
                                    await supabase
                                        .from('children')
                                        .update(payload)
                                        .eq('id', child['id']);
                                  } else {
                                    await supabase
                                        .from('children')
                                        .insert(payload);
                                  }

                                  if (!mounted) return;
                                  if (!sheetCtx.mounted) return;
                                  Navigator.of(sheetCtx).pop();
                                  await _loadAll();
                                  if (!mounted) return;
                                  if (!context.mounted) return;

                                  ScaffoldMessenger.of(this.context)
                                      .showSnackBar(
                                    SnackBar(
                                      content: Text(isEdit
                                          ? 'Child saved: $name'
                                          : 'Child added: $name'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(this.context)
                                      .showSnackBar(
                                    SnackBar(
                                        content: Text('Could not save: $e'),
                                        backgroundColor: Colors.red),
                                  );
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      if (isEdit) ...[
                        const SizedBox(height: 12),
                        Center(
                          child: TextButton(
                            onPressed: () async {
                              final confirmed = await showDialog<bool>(
                                    context: sheetCtx,
                                    builder: (dCtx) => AlertDialog(
                                      title: const Text('Delete child?',
                                          style: TextStyle(
                                              fontFamily: 'SweetAndSalty')),
                                      content: const Text(
                                          'This cannot be undone.',
                                          style: TextStyle(
                                              fontFamily: 'CharlevoixPro')),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(dCtx).pop(false),
                                          child: const Text('Keep',
                                              style: TextStyle(
                                                  fontFamily: 'CharlevoixPro')),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(dCtx).pop(true),
                                          child: const Text('Delete',
                                              style: TextStyle(
                                                  fontFamily: 'CharlevoixPro')),
                                        ),
                                      ],
                                    ),
                                  ) ??
                                  false;

                              if (!confirmed) return;

                              try {
                                await supabase
                                    .from('children')
                                    .delete()
                                    .eq('id', child['id']);

                                if (!mounted) return;
                                if (!sheetCtx.mounted) return;
                                Navigator.of(sheetCtx)
                                    .pop(); // close the sheet only
                                await _loadAll();
                                if (!mounted) return;
                                if (!context.mounted) return;

                                ScaffoldMessenger.of(this.context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Child deleted.'),
                                      backgroundColor: Colors.green),
                                );
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(this.context).showSnackBar(
                                  SnackBar(
                                      content: Text('Could not delete: $e'),
                                      backgroundColor: Colors.red),
                                );
                              }
                            },
                            child: const Text('Delete child',
                                style: TextStyle(color: Colors.red)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );

    nameCtrl.dispose();
    allergiesCtrl.dispose();
    specialNeedsCtrl.dispose();
    emergencyNameCtrl.dispose();
    emergencyPhoneCtrl.dispose();
  }

  // Smaller dropdown (not oversized)
  Widget _ageGroupDropdown(
      {required String? value, required ValueChanged<String?> onChanged}) {
    return DropdownButtonFormField<String?>(
      initialValue: value,
      isExpanded: true,
      isDense: true,
      decoration: InputDecoration(
        labelText: 'Age group (optional)',
        labelStyle: const TextStyle(fontFamily: 'CharlevoixPro'),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      items: [
        const DropdownMenuItem<String?>(
          value: null,
          child: Text('—', style: TextStyle(fontFamily: 'CharlevoixPro')),
        ),
        ..._ageGroups.map(
          (g) => DropdownMenuItem<String?>(
            value: g.value,
            child: Text(g.label,
                style: const TextStyle(fontFamily: 'CharlevoixPro')),
          ),
        ),
      ],
      onChanged: onChanged,
    );
  }

  // ----------------------------
  // Support helpers
  // ----------------------------
  Uri _mailtoUri(String email, {String? subject, String? body}) => Uri(
        scheme: 'mailto',
        path: email,
        queryParameters: {
          if (subject != null) 'subject': subject,
          if (body != null) 'body': body,
        },
      );

  Uri _telUri(String phone) =>
      Uri(scheme: 'tel', path: phone.replaceAll(' ', ''));

  Future<void> _launchUri(Uri uri) async {
    try {
      final ok = await canLaunchUrl(uri);
      if (!ok) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not open link.'),
              backgroundColor: Colors.red),
        );
        return;
      }
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Could not open link.'), backgroundColor: Colors.red),
      );
    }
  }

  // ----------------------------
  // UI
  // ----------------------------
  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
    final isGuest = user == null;

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
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.sageGreen))
            : RefreshIndicator(
                onRefresh: _loadAll,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const SizedBox(height: 6),
                      const Center(
                        child: Text(
                          'Your Profile',
                          style: TextStyle(
                            fontFamily: 'SweetAndSalty',
                            fontSize: 28,
                            color: AppTheme.darkText,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (_error != null) ...[
                        _infoBanner(_error!,
                            background: Colors.red.shade50,
                            border: Colors.red.shade200),
                        const SizedBox(height: 12),
                      ],
                      if (isGuest)
                        _card(
                          title: 'Guest mode',
                          subtitle:
                              'Log in to manage bookings, children profiles and preferences.',
                          leading: const Icon(Icons.person_outline,
                              color: AppTheme.darkText),
                          child: const SizedBox.shrink(),
                        )
                      else ...[
                        _buildHeaderProfileAndMembershipCard(),
                        const SizedBox(height: 12),
                        _buildUpcomingBookingCard(),
                        const SizedBox(height: 12),
                        _buildChildrenCard(),
                        const SizedBox(height: 12),
                        _buildPreferencesAndAllergiesCard(),
                        const SizedBox(height: 12),
                        _buildSettingsCard(),
                        const SizedBox(height: 12),
                        _buildSupportAndFeedbackCard(),
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildHeaderProfileAndMembershipCard() {
    final name = _displayNameFromMe(_me);
    final email =
        (_me?['email'] ?? supabase.auth.currentUser?.email ?? '').toString();
    final phone = (_me?['phone'] ?? '').toString().trim();
    final nickname = (_me?['nickname'] ?? '').toString().trim();
    final genderRaw = (_me?['gender'] ?? '').toString().trim();

    final typeRaw = (_me?['membership_type'] ?? '').toString();
    final statusRaw = (_me?['membership_status'] ?? '').toString();

    final type = _prettyMembershipType(typeRaw);
    final status = _prettyStatus(statusRaw);
    final membershipLine = type.isEmpty
        ? 'No membership'
        : '$type • ${status.isEmpty ? '—' : status}';

    return _card(
      title: name.isEmpty ? 'Your account' : name,
      subtitle: email.isEmpty ? '—' : email,
      leading: _avatarCircle(initials: _initials(name.isEmpty ? email : name)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (nickname.isNotEmpty) _kvRow('Nickname', nickname),
          if (genderRaw.isNotEmpty) _kvRow('Gender', _prettyGender(genderRaw)),
          if (phone.isNotEmpty) _kvRow('Phone', phone),
          const SizedBox(height: 6),
          _kvRow('Membership', membershipLine),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                // Edit profile stays default pink style
                child: NestPrimaryButton(
                  text: 'Edit profile',
                  onPressed: _showEditProfileSheet,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: NestPrimaryButton(
                  text: 'Manage membership',
                  backgroundColor: _profileActionGreen,
                  hoverColor: _profileActionGreenHover,
                  textColor: AppTheme.darkText,
                  onPressed: _showManageMembershipSheet,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingBookingCard() {
    final b = _upcomingBooking;

    if (b == null) {
      return _card(
        title: 'Upcoming booking',
        subtitle: 'No upcoming bookings.',
        leading:
            const Icon(Icons.calendar_today_outlined, color: AppTheme.darkText),
        child: SizedBox(
          width: 240,
          child: NestPrimaryButton(
            text: 'All bookings',
            backgroundColor: _profileActionGreen,
            hoverColor: _profileActionGreenHover,
            textColor: AppTheme.darkText,
            onPressed: _showBookingHistorySheet,
          ),
        ),
      );
    }

    final startLocal = _parseTimeLocal(b['start_time']);
    final endLocal = _parseTimeLocal(b['end_time']);
    final loc = MaterialLocalizations.of(context);

    final date = startLocal == null ? '—' : loc.formatFullDate(startLocal);
    final time = (startLocal == null || endLocal == null)
        ? ''
        : '${loc.formatTimeOfDay(TimeOfDay.fromDateTime(startLocal))} – ${loc.formatTimeOfDay(TimeOfDay.fromDateTime(endLocal))}';

    final wid = _asInt(b['workspace_id']);
    final workspaceName = _workspaceNameById['$wid'];
    final label = (workspaceName != null && workspaceName.trim().isNotEmpty)
        ? workspaceName
        : 'Workspace #$wid';

    return _card(
      title: 'Upcoming booking',
      subtitle: label,
      leading:
          const Icon(Icons.event_available_outlined, color: AppTheme.darkText),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _kvRow('Date', date),
          if (time.isNotEmpty) _kvRow('Time', time),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _cancelBooking(b),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50)),
                    side: BorderSide(color: Colors.red.withValues(alpha: 0.35)),
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 24),
                  ),
                  child: const Text(
                    'Cancel booking',
                    style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.w600,
                        color: Colors.red),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: NestPrimaryButton(
                  text: 'All bookings',
                  backgroundColor: _profileActionGreen,
                  hoverColor: _profileActionGreenHover,
                  textColor: AppTheme.darkText,
                  onPressed: _showBookingHistorySheet,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChildrenCard() {
    final count = _children.length;
    final allAllergies = _allAllergiesFromChildren(_children);
    final allergySummary = allAllergies.isEmpty
        ? 'No allergies saved.'
        : 'Allergies: ${allAllergies.join(', ')}';

    return _card(
      title: 'Children',
      subtitle: count == 0
          ? 'No child profiles yet.'
          : '$count child${count == 1 ? '' : 'ren'}',
      leading: const Icon(Icons.child_care_outlined, color: AppTheme.darkText),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(allergySummary,
              style: const TextStyle(
                  fontFamily: 'CharlevoixPro', color: AppTheme.secondaryText)),
          const SizedBox(height: 12),
          if (_children.isNotEmpty)
            ..._children.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _childTile(c),
                )),
          const SizedBox(height: 4),
          Center(
            child: SizedBox(
              width: 240,
              child: NestPrimaryButton(
                text: 'Add child',
                backgroundColor: _profileActionGreen,
                hoverColor: _profileActionGreenHover,
                textColor: AppTheme.darkText,
                onPressed: () => _showChildEditorSheet(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _childTile(Map<String, dynamic> c) {
    final name = (c['name'] ?? 'Child').toString().trim();
    final ageGroup = (c['age_group'] ?? '').toString().trim();
    final allergies = _stringListFromAny(c['allergies']);
    final dob = _parseDateOnlyLocal(c['date_of_birth']);

    final loc = MaterialLocalizations.of(context);
    final dobLabel = dob == null ? '' : 'Born: ${loc.formatMediumDate(dob)}';

    String ageGroupLabel = '';
    if (ageGroup == 'small') ageGroupLabel = 'Babies (0–2)';
    if (ageGroup == 'big') ageGroupLabel = 'Toddlers (3–5)';

    final meta = [
      if (ageGroupLabel.isNotEmpty) 'Age group: $ageGroupLabel',
      if (dobLabel.isNotEmpty) dobLabel,
      if (allergies.isNotEmpty) 'Allergies: ${allergies.join(', ')}',
    ].join(' • ');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          _avatarCircle(initials: _initials(name)),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                name,
                style: const TextStyle(
                  fontFamily: 'CharlevoixPro',
                  fontWeight: FontWeight.w800,
                  color: AppTheme.darkText,
                ),
              ),
              if (meta.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(meta,
                    style: const TextStyle(
                        fontFamily: 'CharlevoixPro',
                        color: AppTheme.secondaryText)),
              ],
            ]),
          ),
          IconButton(
            tooltip: 'Edit child',
            onPressed: () => _showChildEditorSheet(child: c),
            icon:
                const Icon(Icons.edit_outlined, color: AppTheme.secondaryText),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferencesAndAllergiesCard() {
    final preferredSeat = _preferredWorkspaceLabel();
    final preferredSlot = _preferredTimeSlotLabel();

    return _card(
      title: 'Your Nest preferences',
      subtitle: 'Summary based on your activity',
      leading: const Icon(Icons.tune_outlined, color: AppTheme.darkText),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _kvRow('Preferred seat', preferredSeat),
          _kvRow('Preferred time slot', preferredSlot),
          _kvRow('Visits this month', '${_visitsThisMonth()}'),
          _kvRow('Total visits', '${_totalVisits()}'),
          const SizedBox(height: 10),
          const Text(
            'Allergy information',
            style: TextStyle(
              fontFamily: 'CharlevoixPro',
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppTheme.darkText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _allAllergiesFromChildren(_children).isEmpty
                ? 'No allergies saved in child profiles.'
                : _allAllergiesFromChildren(_children).join(' • '),
            style: const TextStyle(
                fontFamily: 'CharlevoixPro', color: AppTheme.secondaryText),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard() {
    final houseRulesAccepted = (_me?['house_rules_accepted'] == true);

    return _card(
      title: 'Settings',
      subtitle: 'Customize your experience',
      leading: const Icon(Icons.settings_outlined, color: AppTheme.darkText),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            value: _notificationsEnabled,
            onChanged: (v) async {
              setState(() => _notificationsEnabled = v);
              await _setBoolPref(_prefsKeyNotifications, v);

              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Notifications: ${v ? 'ON' : 'OFF'}'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            title: const Text('Notifications',
                style: TextStyle(
                    fontFamily: 'CharlevoixPro', fontWeight: FontWeight.w700)),
            subtitle: const Text('Booking reminders and updates',
                style: TextStyle(fontFamily: 'CharlevoixPro')),
            activeThumbColor: _toggleActiveColor,
            activeTrackColor: _toggleActiveTrackColor,
            contentPadding: EdgeInsets.zero,
          ),
          SwitchListTile(
            value: houseRulesAccepted,
            onChanged: (v) async {
              final user = supabase.auth.currentUser;
              if (user == null) return;

              // optimistic update
              setState(() {
                _me = {
                  ...?_me,
                  'house_rules_accepted': v,
                  'house_rules_accepted_at':
                      v ? DateTime.now().toUtc().toIso8601String() : null,
                };
              });

              try {
                await supabase.from('users').update({
                  'house_rules_accepted': v,
                  'house_rules_accepted_at':
                      v ? DateTime.now().toUtc().toIso8601String() : null,
                }).eq('id', user.id);

                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content:
                        Text('House rules: ${v ? 'ACCEPTED' : 'NOT accepted'}'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('Could not update: $e'),
                      backgroundColor: Colors.red),
                );
                await _loadAll(); // revert
              }
            },
            title: const Text('House rules accepted',
                style: TextStyle(
                    fontFamily: 'CharlevoixPro', fontWeight: FontWeight.w700)),
            subtitle: const Text('Toggle if you agree to the house rules',
                style: TextStyle(fontFamily: 'CharlevoixPro')),
            activeThumbColor: _toggleActiveColor,
            activeTrackColor: _toggleActiveTrackColor,
            contentPadding: EdgeInsets.zero,
          ),
          const Divider(height: 22),
          const Text(
            'Language',
            style: TextStyle(
                fontFamily: 'CharlevoixPro',
                fontWeight: FontWeight.w800,
                color: AppTheme.darkText),
          ),
          const SizedBox(height: 10),
          _languageToggleButtons(),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: NestPrimaryButton(
              text: 'Change password',
              backgroundColor: _profileActionGreen,
              hoverColor: _profileActionGreenHover,
              textColor: AppTheme.darkText,
              onPressed: _showChangePasswordSheet,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Communication preferences',
            style: TextStyle(
                fontFamily: 'CharlevoixPro',
                fontWeight: FontWeight.w800,
                color: AppTheme.darkText),
          ),
          const SizedBox(height: 8),
          _commToggle(
            title: 'Marketing notifications',
            value: _commMarketing,
            onChanged: (v) async {
              setState(() => _commMarketing = v);
              await _setBoolPref(_prefsKeyCommMarketing, v);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content:
                        Text('Marketing notifications: ${v ? 'ON' : 'OFF'}'),
                    backgroundColor: Colors.green),
              );
            },
          ),
          _commToggle(
            title: 'Emails',
            value: _commEmail,
            onChanged: (v) async {
              setState(() => _commEmail = v);
              await _setBoolPref(_prefsKeyCommEmail, v);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('Emails: ${v ? 'ON' : 'OFF'}'),
                    backgroundColor: Colors.green),
              );
            },
          ),
          _commToggle(
            title: 'Phone calls',
            value: _commPhone,
            onChanged: (v) async {
              setState(() => _commPhone = v);
              await _setBoolPref(_prefsKeyCommPhone, v);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('Phone calls: ${v ? 'ON' : 'OFF'}'),
                    backgroundColor: Colors.green),
              );
            },
          ),
          _commToggle(
            title: 'Tracking',
            value: _commTracking,
            onChanged: (v) async {
              setState(() => _commTracking = v);
              await _setBoolPref(_prefsKeyCommTracking, v);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('Tracking: ${v ? 'ON' : 'OFF'}'),
                    backgroundColor: Colors.green),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _languageToggleButtons() {
    final selectedDe = _language == 'de';
    final selectedEn = _language == 'en';

    return Row(
      children: [
        Expanded(
          child: NestPrimaryButton(
            text: 'Deutsch',
            backgroundColor: selectedDe ? _profileActionGreen : Colors.white,
            hoverColor:
                selectedDe ? _profileActionGreenHover : const Color(0xFFF3F3F3),
            textColor: AppTheme.darkText,
            onPressed: () => _setLanguage('de'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: NestPrimaryButton(
            text: 'English',
            backgroundColor: selectedEn ? _profileActionGreen : Colors.white,
            hoverColor:
                selectedEn ? _profileActionGreenHover : const Color(0xFFF3F3F3),
            textColor: AppTheme.darkText,
            onPressed: () => _setLanguage('en'),
          ),
        ),
      ],
    );
  }

  Widget _buildSupportAndFeedbackCard() {
    return _card(
      title: 'Support & contact',
      subtitle: 'We’re here to help',
      leading:
          const Icon(Icons.support_agent_outlined, color: AppTheme.darkText),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _supportRow(Icons.email, _nestEmail),
          const SizedBox(height: 8),
          _supportRow(Icons.phone, _nestPhone),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: NestPrimaryButton(
                  text: 'Email',
                  backgroundColor: _profileActionGreen,
                  hoverColor: _profileActionGreenHover,
                  textColor: AppTheme.darkText,
                  onPressed: () => _launchUri(
                      _mailtoUri(_nestEmail, subject: 'Support request')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: NestPrimaryButton(
                  text: 'Call',
                  backgroundColor: _profileActionGreen,
                  hoverColor: _profileActionGreenHover,
                  textColor: AppTheme.darkText,
                  onPressed: () => _launchUri(_telUri(_nestPhone)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: () => _launchUri(
              _mailtoUri(
                _nestEmail,
                subject: 'App feedback',
                body: 'Hi Nest team,\n\nI have feedback:\n\n',
              ),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Give feedback',
                style: TextStyle(
                  fontFamily: 'CharlevoixPro',
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.underline,
                  color: AppTheme.darkText,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------
  // UI helpers
  // ----------------------------
  Widget _commToggle(
      {required String title,
      required bool value,
      required ValueChanged<bool> onChanged}) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      title: Text(title,
          style: const TextStyle(
              fontFamily: 'CharlevoixPro', fontWeight: FontWeight.w700)),
      contentPadding: EdgeInsets.zero,
      activeThumbColor: _toggleActiveColor,
      activeTrackColor: _toggleActiveTrackColor,
    );
  }

  ButtonStyle _outlinedPillStyle() => OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
        side: BorderSide(color: Colors.black.withValues(alpha: 0.18)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
      );

  Widget _pillAction(
      {required String label,
      required VoidCallback onPressed,
      required IconData icon}) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: AppTheme.secondaryText),
      label: Text(
        label,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontFamily: 'CharlevoixPro',
          color: AppTheme.darkText,
          fontWeight: FontWeight.w700,
        ),
      ),
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
        side: BorderSide(color: Colors.black.withValues(alpha: 0.18)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
      ),
    );
  }

  Widget _textField({
    required String label,
    required TextEditingController controller,
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(fontFamily: 'CharlevoixPro'),
        hintStyle: const TextStyle(fontFamily: 'CharlevoixPro'),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: AppTheme.bookingButtonColor.withValues(alpha: 0.9),
              width: 2),
        ),
      ),
      style: const TextStyle(fontFamily: 'CharlevoixPro'),
    );
  }

  Widget _supportRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.darkText),
        const SizedBox(width: 10),
        Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontFamily: 'CharlevoixPro', color: AppTheme.darkText))),
      ],
    );
  }

  Widget _infoBanner(String text,
      {required Color background, required Color border}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Text(text,
          style: const TextStyle(
              fontFamily: 'CharlevoixPro', color: AppTheme.darkText)),
    );
  }

  Widget _card({
    required String title,
    required String subtitle,
    required Widget leading,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              leading,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontFamily: 'CharlevoixPro',
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.darkText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontFamily: 'CharlevoixPro',
                          fontSize: 13,
                          color: AppTheme.secondaryText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ]),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            blurRadius: 10,
            offset: const Offset(0, 4),
            color: Colors.black.withValues(alpha: 0.06),
          )
        ],
      );

  Widget _avatarCircle({required String initials}) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppTheme.creamBackground,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            fontFamily: 'CharlevoixPro',
            fontWeight: FontWeight.w900,
            color: AppTheme.darkText,
          ),
        ),
      ),
    );
  }

  Widget _kvRow(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              k,
              style: const TextStyle(
                  fontFamily: 'CharlevoixPro', color: AppTheme.secondaryText),
            ),
          ),
          Text(
            v,
            style: const TextStyle(
              fontFamily: 'CharlevoixPro',
              fontWeight: FontWeight.w800,
              color: AppTheme.darkText,
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------
  // Data helpers / calculations
  // ----------------------------
  int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  DateTime? _parseTimeLocal(dynamic raw) {
    if (raw == null) return null;
    try {
      return DateTime.parse(raw.toString()).toLocal();
    } catch (_) {
      return null;
    }
  }

  DateTime? _parseDateOnlyLocal(dynamic raw) {
    if (raw == null) return null;
    final s = raw.toString().trim();
    if (s.isEmpty) return null;
    try {
      return DateTime.parse(s);
    } catch (_) {
      return null;
    }
  }

  String _dateOnlyIso(DateTime d) {
    final dd = DateTime(d.year, d.month, d.day);
    final mm = dd.month.toString().padLeft(2, '0');
    final day = dd.day.toString().padLeft(2, '0');
    return '${dd.year}-$mm-$day';
  }

  String _displayNameFromMe(Map<String, dynamic>? me) {
    final full = (me?['full_name'] ?? '').toString().trim();
    if (full.isNotEmpty) return full;
    return '';
  }

  String _prettyStatus(String raw) {
    final s = raw.trim().toLowerCase();
    if (s.isEmpty) return '';
    return s[0].toUpperCase() + s.substring(1);
  }

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
      case 'day pass':
        return 'Day Pass';
      case 'flexipass':
      case 'flexi_pass':
      case 'flexi-pass':
        return 'Flexi-Pass';
      case 'none':
        return '';
      default:
        if (t.isEmpty) return '';
        return t[0].toUpperCase() + t.substring(1);
    }
  }

  String _prettyGender(String raw) {
    final v = raw.trim().toLowerCase();
    switch (v) {
      case 'female':
        return 'Female';
      case 'male':
        return 'Male';
      case 'diverse':
        return 'Diverse';
      case 'prefer_not_to_say':
        return 'Prefer not to say';
      default:
        if (raw.trim().isEmpty) return '';
        // Fallback: show whatever is stored
        return raw.trim();
    }
  }

  String _initials(String s) {
    final trimmed = s.trim();
    if (trimmed.isEmpty) return 'N';
    final parts =
        trimmed.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  List<String> _stringListFromAny(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) {
      return raw
          .map((e) => e.toString().trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    if (raw is String) {
      return raw
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return [];
  }

  List<String> _allAllergiesFromChildren(List<Map<String, dynamic>> kids) {
    final set = <String>{};
    for (final c in kids) {
      for (final a in _stringListFromAny(c['allergies'])) {
        set.add(a);
      }
    }
    final list = set.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  int _totalVisits() {
    final all = [..._futureBookings, ..._pastBookings];
    return all.where((b) => _isConfirmed(b['status'])).length;
  }

  int _visitsThisMonth() {
    final now = DateTime.now();
    final all = [..._futureBookings, ..._pastBookings];
    int count = 0;
    for (final b in all) {
      if (!_isConfirmed(b['status'])) continue;
      final start = _parseTimeLocal(b['start_time']);
      if (start == null) continue;
      if (start.year == now.year && start.month == now.month) count++;
    }
    return count;
  }

  String _preferredWorkspaceLabel() {
    final all = [..._futureBookings, ..._pastBookings]
        .where((b) => _isConfirmed(b['status']))
        .toList();
    if (all.isEmpty) return 'Not enough data yet';

    final counts = <int, int>{};
    for (final b in all) {
      final wid = _asInt(b['workspace_id']);
      if (wid <= 0) continue;
      counts[wid] = (counts[wid] ?? 0) + 1;
    }
    if (counts.isEmpty) return 'Not enough data yet';

    final top = counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    final name = _workspaceNameById['$top'];
    if (name != null && name.trim().isNotEmpty) return name;
    return 'Workspace #$top';
  }

  String _preferredTimeSlotLabel() {
    final all = [..._futureBookings, ..._pastBookings]
        .where((b) => _isConfirmed(b['status']))
        .toList();
    if (all.isEmpty) return 'Not enough data yet';

    final counts = <String, int>{};

    for (final b in all) {
      final start = _parseTimeLocal(b['start_time']);
      final end = _parseTimeLocal(b['end_time']);
      if (start == null || end == null) continue;

      final duration = end.difference(start);
      String slot;

      if (duration.inHours >= 7) {
        slot = 'Full day';
      } else {
        final h = start.hour;
        if (h < 11) {
          slot = 'Morning';
        } else if (h < 14) {
          slot = 'Midday';
        } else {
          slot = 'Afternoon';
        }
      }

      counts[slot] = (counts[slot] ?? 0) + 1;
    }

    if (counts.isEmpty) return 'Not enough data yet';
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }
}

class _AgeGroupItem {
  final String value;
  final String label;
  const _AgeGroupItem({required this.value, required this.label});
}
