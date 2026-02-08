import 'package:flutter/material.dart';
import 'package:nest_app/core/theme/app_theme.dart';
import 'package:nest_app/widgets/nest_app_bar.dart';
import 'package:nest_app/widgets/nest_button.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onNavigateToSchedule;
  final VoidCallback? onNavigateToMembership;

  const HomeScreen({
    super.key,
    this.onNavigateToSchedule,
    this.onNavigateToMembership,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _profileRow;

  Map<String, dynamic>? _waitlistRow;
  bool _loadingProfile = false;
  bool _loadingWaitlist = false;

  bool _aboutShownThisSession = false;

  @override
  void initState() {
    super.initState();
    _refreshAll();

    // For development reasons: always show About NEST after login.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (_aboutShownThisSession) return;
      _aboutShownThisSession = true;
      await _showAboutNestDialog(context);
    });
  }

  Future<void> _refreshAll() async {
    await _loadProfileRow();
    await _loadWaitlistRow();
  }

  String? _stringOrNull(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  Map<String, String> _splitFullName(String fullName) {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.trim().isNotEmpty)
        .toList();

    if (parts.isEmpty) return {'first': '', 'last': ''};
    if (parts.length == 1) return {'first': parts.first, 'last': ''};

    return {
      'first': parts.first,
      'last': parts.sublist(1).join(' '),
    };
  }

  Future<void> _loadProfileRow() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;
    if (_loadingProfile) return;

    setState(() => _loadingProfile = true);
    try {
      final row =
          await supabase.from('users').select().eq('id', user.id).maybeSingle();
      if (!mounted) return;
      setState(() => _profileRow = row);
    } catch (_) {
      // fall back gracefully if blocked by RLS/missing row
    } finally {
      if (!mounted) return;
      setState(() => _loadingProfile = false);
    }
  }

  Future<void> _loadWaitlistRow() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;
    if (_loadingWaitlist) return;

    setState(() => _loadingWaitlist = true);
    try {
      final rows = await supabase
          .from('welcoming_party_waitlist')
          .select()
          .eq('user_id', user.id)
          .limit(1);

      Map<String, dynamic>? row;
      if (rows.isNotEmpty) {
        row = (rows.first as Map).cast<String, dynamic>();
      }

      if (!mounted) return;
      setState(() => _waitlistRow = row);
    } catch (_) {
      // if SELECT is blocked by RLS, status won't be available
    } finally {
      if (!mounted) return;
      setState(() => _loadingWaitlist = false);
    }
  }

  String _greetingText() {
    // Requirement: greeting name must come from profile full_name.
    final fullName = _stringOrNull(_profileRow?['full_name']);
    if (fullName == null) return 'Welcome back';
    return 'Welcome back, $fullName';
  }

  bool get _hasJoinedWaitlist => _waitlistRow != null;

  String _statusValue() {
    final s = _stringOrNull(_waitlistRow?['status'])?.toLowerCase();
    return s ?? 'waitlisted';
  }

  String _friendlyStatusTitle(String status) {
    switch (status) {
      case 'invited':
        return 'You’re invited! 🎉';
      case 'confirmed':
        return 'You’re confirmed! 🥳';
      case 'declined':
        return 'Update on your request';
      case 'waitlisted':
      default:
        return 'You’re on the waitlist ⭐️';
    }
  }

  String _friendlyStatusMessage(String status) {
    switch (status) {
      case 'invited':
        return "Good news — you’re invited to the welcoming party.\n\nWe’ll reach out with the final details (and anything you need to know before the event).";
      case 'confirmed':
        return "You’re officially confirmed for the welcoming party.\n\nWe can’t wait to celebrate with you — see you soon!";
      case 'declined':
        return "Thanks so much for signing up.\n\nAt the moment we can’t offer you a spot for this event — but we’ll keep you posted about the next one.";
      case 'waitlisted':
      default:
        return "Thanks for signing up!\n\nYour request is currently on the waitlist. Because of the high demand, we first need to review registrations before we can confirm anyone.\n\nWe’ll contact you soon, and you’ll be informed if you’re officially invited.";
    }
  }

  Future<void> _showStatusPopup(BuildContext context) async {
    final status = _statusValue();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        actionsAlignment: MainAxisAlignment.center,
        title: Text(
          _friendlyStatusTitle(status),
          style: const TextStyle(fontFamily: 'SweetAndSalty'),
        ),
        content: Text(
          _friendlyStatusMessage(status),
          style: const TextStyle(fontFamily: 'CharlevoixPro'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Okay',
                style: TextStyle(fontFamily: 'CharlevoixPro')),
          ),
        ],
      ),
    );
  }

  bool _isWithinMinutes(DateTime now, int startMin, int endMin) {
    final minutes = now.hour * 60 + now.minute;
    return minutes >= startMin && minutes < endMin;
  }

  bool _isCoworkingOpenNow(DateTime now) {
    // Mon–Fri 8:30–18:30
    final weekday = now.weekday; // Mon=1 ... Sun=7
    final isWeekday = weekday >= DateTime.monday && weekday <= DateTime.friday;
    if (!isWeekday) return false;
    return _isWithinMinutes(now, 8 * 60 + 30, 18 * 60 + 30);
  }

  bool _isCafeOpenNow(DateTime now) {
    // Daily 10:00–17:00
    return _isWithinMinutes(now, 10 * 60, 17 * 60);
  }

  bool _isNestOpenNow(DateTime now) {
    // Consider NEST "open" if either coworking OR café is open.
    return _isCoworkingOpenNow(now) || _isCafeOpenNow(now);
  }

  Future<void> _showAboutNestDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const Text(
                    'Meet NEST – CoWork & Play',
                    style: TextStyle(
                      fontFamily: 'SweetAndSalty',
                      fontSize: 28,
                      color: AppTheme.darkText,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Your coworking and community space in Hamburg Uhlenhorst, designed for parents with babies & toddlers (0–5).',
                    style: TextStyle(
                      fontFamily: 'CharlevoixPro',
                      fontSize: 16,
                      color: AppTheme.secondaryText,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      'assets/images/delia and melissa.jpeg',
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Founded by two moms while literally working from playground benches... NEST was built to solve the problem parents actually live.',
                    style: TextStyle(
                      fontFamily: 'CharlevoixPro',
                      fontSize: 14,
                      color: AppTheme.secondaryText,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '🧘 Focus-friendly workspace\n'
                      '🧸 Montessori-inspired childcare\n'
                      '🤝 Supportive community\n'
                      '☕ Family café & classes\n',
                      style: TextStyle(
                        fontFamily: 'CharlevoixPro',
                        fontSize: 14,
                        color: AppTheme.darkText,
                        height: 1.6,
                      ),
                      textAlign: TextAlign.left,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Here, you can work with focus and stay close to your child — so everyone thrives.',
                    style: TextStyle(
                      fontFamily: 'CharlevoixPro',
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkText,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  Center(
                    child: SizedBox(
                      width: 160,
                      child: NestPrimaryButton(
                        text: 'Got it',
                        onPressed: () => Navigator.of(ctx).pop(),
                        backgroundColor: AppTheme.bookingButtonColor,
                        textColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmAndLogout(BuildContext context) async {
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

    await Supabase.instance.client.auth.signOut();
    if (!context.mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  void _goSchedule(BuildContext context) {
    if (widget.onNavigateToSchedule != null) {
      widget.onNavigateToSchedule!.call();
      return;
    }
    Navigator.of(context).pushNamed('/schedule');
  }

  void _goCafe(BuildContext context) {
    Navigator.of(context).pushNamed('/cafe');
  }

  void _goMembership(BuildContext context) {
    if (widget.onNavigateToMembership != null) {
      widget.onNavigateToMembership!.call();
      return;
    }
    Navigator.of(context).pushNamed('/membership');
  }

  Future<void> _openWaitlistFlow(BuildContext context) async {
    if (_hasJoinedWaitlist) {
      await _showStatusPopup(context);
      return;
    }
    await _joinWaitlist(context);
  }

  Future<void> _joinWaitlist(BuildContext context) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (_profileRow == null && !_loadingProfile) {
      await _loadProfileRow();
    }

    final fullName = _stringOrNull(_profileRow?['full_name']);
    final split =
        fullName != null ? _splitFullName(fullName) : {'first': '', 'last': ''};

    final emailCtrl = TextEditingController(text: user?.email ?? '');
    final firstNameCtrl = TextEditingController(text: split['first'] ?? '');
    final lastNameCtrl = TextEditingController(text: split['last'] ?? '');
    final phoneCtrl = TextEditingController();
    final childrenAgesCtrl = TextEditingController();

    final formKey = GlobalKey<FormState>();

    int attendees = 1;
    int numberOfChildren = 1;
    bool submitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (sheetCtx, setModalState) {
            Future<void> submit() async {
              if (submitting) return;
              if (!(formKey.currentState?.validate() ?? false)) return;

              setModalState(() => submitting = true);

              try {
                await supabase.from('welcoming_party_waitlist').insert({
                  'email': emailCtrl.text.trim(),
                  'first_name': firstNameCtrl.text.trim(),
                  'last_name': lastNameCtrl.text.trim(),
                  'phone': phoneCtrl.text.trim().isEmpty
                      ? null
                      : phoneCtrl.text.trim(),
                  'attendees': attendees,
                  'number_of_children': numberOfChildren,
                  'children_ages': childrenAgesCtrl.text.trim().isEmpty
                      ? null
                      : childrenAgesCtrl.text.trim(),
                  'user_id': user?.id,
                });

                if (!sheetCtx.mounted) return;
                Navigator.of(sheetCtx).pop();

                await _loadWaitlistRow();

                if (!context.mounted) return;

                await showDialog<void>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    actionsAlignment: MainAxisAlignment.center,
                    title: const Text('You’re on the list!',
                        style: TextStyle(fontFamily: 'SweetAndSalty')),
                    content: const Text(
                      "Thanks for signing up — we’re so happy you want to join.\n\nBecause of the high demand, we first need to review registrations before we can confirm anyone.\n\nWe’ll contact you soon, and you’ll be informed if you’re officially invited.",
                      style: TextStyle(fontFamily: 'CharlevoixPro'),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Okay',
                            style: TextStyle(fontFamily: 'CharlevoixPro')),
                      ),
                    ],
                  ),
                );
              } catch (e) {
                if (!sheetCtx.mounted) return;
                ScaffoldMessenger.of(sheetCtx).showSnackBar(
                  SnackBar(
                    content: Text('Could not join the waitlist: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              } finally {
                if (!sheetCtx.mounted) return;
                setModalState(() => submitting = false);
              }
            }

            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 18,
                  bottom: 18 + MediaQuery.of(sheetCtx).viewInsets.bottom,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                          child: Image.asset('assets/images/nest_logo.png',
                              height: 46)),
                      const SizedBox(height: 10),
                      const Text(
                        'Welcoming Party Waitlist',
                        style: TextStyle(
                          fontFamily: 'SweetAndSalty',
                          fontSize: 28,
                          color: AppTheme.darkText,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Leave your details and we’ll keep you posted.',
                        style: TextStyle(
                          fontFamily: 'CharlevoixPro',
                          fontSize: 14,
                          color: AppTheme.secondaryText,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Form(
                        key: formKey,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: emailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email],
                              decoration: const InputDecoration(
                                labelText: 'Email address',
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) {
                                final s = (v ?? '').trim();
                                if (s.isEmpty) {
                                  return 'Please enter your email.';
                                }
                                if (!s.contains('@')) {
                                  return 'Please enter a valid email.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: firstNameCtrl,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.givenName],
                              decoration: const InputDecoration(
                                labelText: 'First name',
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) => (v ?? '').trim().isEmpty
                                  ? 'Please enter your first name.'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: lastNameCtrl,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.familyName],
                              decoration: const InputDecoration(
                                labelText: 'Family name',
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) => (v ?? '').trim().isEmpty
                                  ? 'Please enter your family name.'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: phoneCtrl,
                              keyboardType: TextInputType.phone,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [
                                AutofillHints.telephoneNumber
                              ],
                              decoration: const InputDecoration(
                                labelText: 'Phone number (optional)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 14),
                            _StepperTile(
                              title: 'Number of attendees',
                              value: attendees,
                              min: 1,
                              max: 20,
                              submitting: submitting,
                              onChanged: (v) =>
                                  setModalState(() => attendees = v),
                            ),
                            const SizedBox(height: 12),
                            _StepperTile(
                              title: 'Number of children',
                              value: numberOfChildren,
                              min: 0,
                              max: 10,
                              submitting: submitting,
                              onChanged: (v) =>
                                  setModalState(() => numberOfChildren = v),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: childrenAgesCtrl,
                              textInputAction: TextInputAction.done,
                              minLines: 1,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                labelText: 'Age of children (optional)',
                                hintText: 'e.g. 2, 4  or  18 months, 3 years',
                                border: OutlineInputBorder(),
                              ),
                              onFieldSubmitted: (_) => submit(),
                            ),
                            const SizedBox(height: 18),
                            NestPrimaryButton(
                              text: submitting
                                  ? 'Submitting...'
                                  : 'Join waitlist',
                              onPressed: submitting ? () {} : submit,
                              backgroundColor: AppTheme.bookingButtonColor,
                              textColor: Colors.white,
                            ),
                            const SizedBox(height: 10),
                            TextButton(
                              onPressed: submitting
                                  ? null
                                  : () => Navigator.of(sheetCtx).pop(),
                              child: const Text('Cancel',
                                  style:
                                      TextStyle(fontFamily: 'CharlevoixPro')),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final greeting = _greetingText();
    final now = DateTime.now();

    final coworkingOpen = _isCoworkingOpenNow(now);
    final cafeOpen = _isCafeOpenNow(now);
    final nestOpen = _isNestOpenNow(now);

    final openingBg =
        nestOpen ? const Color(0xFFB2E5D1) : const Color(0xFFFF5757);
    const openingTextColor = Colors.white;

    final waitlistBg = const Color(0xFFFFDE59);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: NestAppBar(
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout, color: AppTheme.darkText),
            onPressed: () => _confirmAndLogout(context),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 18),
              Center(
                child: Text(
                  greeting,
                  style: const TextStyle(
                    fontFamily: 'SweetAndSalty',
                    fontSize: 30,
                    color: AppTheme.darkText,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 6),
              const Center(
                child: Text(
                  'Ready to be productive today?',
                  style: TextStyle(
                    fontFamily: 'CharlevoixPro',
                    fontSize: 16,
                    color: AppTheme.secondaryText,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 28),

              const _SectionTitle(title: 'Quick Actions'),
              const SizedBox(height: 12),
              _Card(
                child: Row(
                  children: [
                    Expanded(
                      child: NestPrimaryButton(
                        text: 'BOOK DESK',
                        onPressed: () => _goSchedule(context),
                        backgroundColor: AppTheme.bookingButtonColor,
                        textColor: AppTheme.bookingButtonTextColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _HoverNestButton(
                        text: 'ORDER COFFEE',
                        onPressed: () => _goCafe(context),
                        backgroundColor: const Color(0xFFFFBD59),
                        hoverBackgroundColor: const Color(0xFFF87CC8),
                        textColor: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // PARTY / WAITLIST SECTION
              _InfoCard(
                icon: Icons.celebration_outlined,
                backgroundColor: waitlistBg,
                leadingWidget: const Text('🥳', style: TextStyle(fontSize: 20)),
                title: 'Upcoming Event',
                content: 'Grand opening event - 16 March 2026',
                subcontent: _hasJoinedWaitlist
                    ? "You’re signed up. Tap below to check your current status."
                    : "Due to high demand, we first need to review registrations before we can confirm anyone — but we’d love to have you with us.",
                footer: Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Center(
                    child: SizedBox(
                      width: 200,
                      child: NestPrimaryButton(
                        text: _hasJoinedWaitlist
                            ? 'Check your status'
                            : 'Join waitlist',
                        onPressed: () => _openWaitlistFlow(context),
                        backgroundColor: AppTheme.bookingButtonColor,
                        textColor: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ready to Make Work & Family Actually Fit Together?',
                      style: TextStyle(
                        fontFamily: 'CharlevoixPro',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkText,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'We open in March 2026!\nOur first location is coming to Hamburg-Uhlenhorst soon. Spots are limited to keep groups small & personal. Join the waitlist now – no commitment, and get a special early-bird discount if you become a member.',
                      style: TextStyle(
                        fontFamily: 'CharlevoixPro',
                        fontSize: 14,
                        height: 1.5,
                        color: AppTheme.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: SizedBox(
                        width: 210,
                        child: NestPrimaryButton(
                          text: 'Choose membership',
                          onPressed: () => _goMembership(context),
                          backgroundColor: const Color(0xFFFF5757),
                          textColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // NEW LOCATION SECTION (above opening hours)
              const _SectionTitle(title: 'Located in the heart of Hamburg'),
              const SizedBox(height: 12),
              const _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📍 Find us here',
                      style: TextStyle(
                        fontFamily: 'CharlevoixPro',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkText,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Hofweg. 70\n22087 Hamburg',
                      style: TextStyle(
                        fontFamily: 'CharlevoixPro',
                        fontSize: 14,
                        height: 1.4,
                        color: AppTheme.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // OPENING HOURS (dynamic background + bold per open section)
              _InfoCard(
                backgroundColor: openingBg,
                iconColor: openingTextColor,
                titleColor: openingTextColor,
                contentColor: openingTextColor,
                subcontentColor: openingTextColor.withOpacity(0.95),
                icon: nestOpen
                    ? Icons.access_time_filled_rounded
                    : Icons.lock_clock,
                title: nestOpen
                    ? 'We’re open right now'
                    : 'We’re currently closed',
                content: '',
                subcontent: '',
                contentWidget: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CoWorking: Mo–Fr 8:30–18:30',
                      style: TextStyle(
                        fontFamily: 'CharlevoixPro',
                        fontSize: 16,
                        fontWeight:
                            coworkingOpen ? FontWeight.bold : FontWeight.normal,
                        color: openingTextColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Family Café: Daily 10:00–17:00',
                      style: TextStyle(
                        fontFamily: 'CharlevoixPro',
                        fontSize: 14,
                        fontWeight:
                            cafeOpen ? FontWeight.bold : FontWeight.normal,
                        color: openingTextColor.withOpacity(0.95),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepperTile extends StatelessWidget {
  final String title;
  final int value;
  final int min;
  final int max;
  final bool submitting;
  final ValueChanged<int> onChanged;

  const _StepperTile({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.submitting,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontFamily: 'CharlevoixPro',
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.darkText,
              ),
            ),
          ),
          IconButton(
            onPressed: submitting
                ? null
                : () => onChanged((value - 1).clamp(min, max)),
            icon: const Icon(Icons.remove_circle_outline),
          ),
          Text(
            value.toString(),
            style: const TextStyle(
              fontFamily: 'CharlevoixPro',
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          IconButton(
            onPressed: submitting
                ? null
                : () => onChanged((value + 1).clamp(min, max)),
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
    );
  }
}

/// Improved hover: smoothly interpolates button color.
/// Note: Hover effects only appear on desktop/web (not on iOS/Android touch).
class _HoverNestButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  final Color backgroundColor;
  final Color hoverBackgroundColor;
  final Color textColor;

  const _HoverNestButton({
    required this.text,
    required this.onPressed,
    required this.backgroundColor,
    required this.hoverBackgroundColor,
    required this.textColor,
  });

  @override
  State<_HoverNestButton> createState() => _HoverNestButtonState();
}

class _HoverNestButtonState extends State<_HoverNestButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final target =
        _hovered ? widget.hoverBackgroundColor : widget.backgroundColor;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: target),
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        builder: (context, color, child) {
          return NestPrimaryButton(
            text: widget.text,
            onPressed: widget.onPressed,
            backgroundColor: color ?? target,
            textColor: widget.textColor,
          );
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontFamily: 'CharlevoixPro',
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppTheme.darkText,
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  final Color? backgroundColor;

  const _Card({required this.child, this.backgroundColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            blurRadius: 10,
            offset: const Offset(0, 4),
            color: Colors.black.withOpacity(0.05),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String content;
  final String subcontent;
  final Widget? footer;

  final Color? backgroundColor;

  final Color? iconColor;
  final Color? titleColor;
  final Color? contentColor;
  final Color? subcontentColor;

  // New: for colorful emojis or custom leading (like 🥳)
  final Widget? leadingWidget;

  // New: allow richer content (e.g., bold lines)
  final Widget? contentWidget;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.content,
    required this.subcontent,
    this.footer,
    this.backgroundColor,
    this.iconColor,
    this.titleColor,
    this.contentColor,
    this.subcontentColor,
    this.leadingWidget,
    this.contentWidget,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      backgroundColor: backgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              leadingWidget ??
                  Icon(icon,
                      color: iconColor ?? AppTheme.secondaryText, size: 20),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'CharlevoixPro',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: titleColor ?? AppTheme.darkText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (contentWidget != null) ...[
            contentWidget!,
          ] else ...[
            Text(
              content,
              style: TextStyle(
                fontFamily: 'CharlevoixPro',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: contentColor ?? AppTheme.darkText,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subcontent,
              style: TextStyle(
                fontFamily: 'CharlevoixPro',
                fontSize: 14,
                color: subcontentColor ?? AppTheme.secondaryText,
                height: 1.35,
              ),
            ),
          ],
          if (footer != null) footer!,
        ],
      ),
    );
  }
}
