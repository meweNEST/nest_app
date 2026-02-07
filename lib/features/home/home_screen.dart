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
  bool _loadingProfile = false;

  @override
  void initState() {
    super.initState();
    _loadProfileRow();
  }

  String? _stringOrNull(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  Future<void> _loadProfileRow() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    if (_loadingProfile) return;

    setState(() => _loadingProfile = true);

    try {
      final row = await supabase.from('users').select().eq('id', user.id).maybeSingle();

      if (!mounted) return;
      setState(() => _profileRow = row);
    } catch (_) {
      // If we can't read the profile due to RLS or missing row,
      // we simply fall back to "Welcome back" and manual form entry.
    } finally {
      if (!mounted) return;
      setState(() => _loadingProfile = false);
    }
  }

  /// Requirement:
  /// - The "Welcome back" name must come from the profile (public.users).
  /// - If not set: show ALWAYS just "Welcome back".
  String? _profileDisplayName() {
    final row = _profileRow;
    if (row == null) return null;

    // Adjust priority here if needed:
    // If your profile uses "nickname" as the main display name,
    // keep it early in the list (it is).
    final direct = _stringOrNull(
      row['nickname'] ??
          row['full_name'] ??
          row['name'] ??
          row['first_name'],
    );
    if (direct != null) return direct;

    final first = _stringOrNull(row['first_name']);
    final last = _stringOrNull(row['last_name'] ?? row['family_name']);
    final combined = [first, last].whereType<String>().join(' ').trim();
    return combined.isEmpty ? null : combined;
  }

  /// Phone prefilling: if profile has a phone column, we fill it automatically.
  String? _profilePhone() {
    final row = _profileRow;
    if (row == null) return null;
    return _stringOrNull(row['phone'] ?? row['phone_number'] ?? row['mobile']);
  }

  String _greetingText() {
    final name = _profileDisplayName();
    if (name == null || name.isEmpty) return 'Welcome back';
    return 'Welcome back, $name';
  }

  Future<void> _confirmAndLogout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Logout?',
          style: TextStyle(fontFamily: 'SweetAndSalty'),
        ),
        content: const Text(
          'Are you sure you want to log out?',
          style: TextStyle(fontFamily: 'CharlevoixPro'),
        ),
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

  Future<void> _joinWaitlist(BuildContext context) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    // Ensure we tried to load profile before opening the form (helps prefilling).
    if (_profileRow == null && !_loadingProfile) {
      await _loadProfileRow();
    }

    final emailCtrl = TextEditingController(text: user?.email ?? '');
    final firstNameCtrl = TextEditingController(text: _stringOrNull(_profileRow?['first_name']) ?? '');
    final lastNameCtrl = TextEditingController(
      text: _stringOrNull(_profileRow?['last_name'] ?? _profileRow?['family_name']) ?? '',
    );
    final phoneCtrl = TextEditingController(text: _profilePhone() ?? '');
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
                  'phone': phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                  'attendees': attendees,
                  'number_of_children': numberOfChildren,
                  'children_ages': childrenAgesCtrl.text.trim().isEmpty ? null : childrenAgesCtrl.text.trim(),
                  'user_id': user?.id,
                  // status is handled by DB default: 'waitlisted'
                });

                if (!sheetCtx.mounted) return;
                Navigator.of(sheetCtx).pop();

                if (!context.mounted) return;

                // Warm “quick pop up” confirmation
                await showDialog<void>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text(
                      'You’re on the list!',
                      style: TextStyle(fontFamily: 'SweetAndSalty'),
                    ),
                    content: const Text(
                      "Thanks for signing up — we’re so happy you want to join.\n\nWe’ll contact you soon, and you’ll be informed if you’re officially invited.",
                      style: TextStyle(fontFamily: 'CharlevoixPro'),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Okay', style: TextStyle(fontFamily: 'CharlevoixPro')),
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
                      Center(child: Image.asset('assets/images/nest_logo.png', height: 46)),
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
                                if (s.isEmpty) return 'Please enter your email.';
                                if (!s.contains('@')) return 'Please enter a valid email.';
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
                              validator: (v) =>
                              (v ?? '').trim().isEmpty ? 'Please enter your first name.' : null,
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
                              autofillHints: const [AutofillHints.telephoneNumber],
                              decoration: const InputDecoration(
                                labelText: 'Phone number (optional)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.black.withOpacity(0.08)),
                              ),
                              child: Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Number of attendees',
                                      style: TextStyle(
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
                                        : () => setModalState(
                                          () => attendees = (attendees - 1).clamp(1, 20),
                                    ),
                                    icon: const Icon(Icons.remove_circle_outline),
                                  ),
                                  Text(
                                    attendees.toString(),
                                    style: const TextStyle(
                                      fontFamily: 'CharlevoixPro',
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: submitting
                                        ? null
                                        : () => setModalState(
                                          () => attendees = (attendees + 1).clamp(1, 20),
                                    ),
                                    icon: const Icon(Icons.add_circle_outline),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.black.withOpacity(0.08)),
                              ),
                              child: Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Number of children',
                                      style: TextStyle(
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
                                        : () => setModalState(
                                          () => numberOfChildren =
                                          (numberOfChildren - 1).clamp(0, 10),
                                    ),
                                    icon: const Icon(Icons.remove_circle_outline),
                                  ),
                                  Text(
                                    numberOfChildren.toString(),
                                    style: const TextStyle(
                                      fontFamily: 'CharlevoixPro',
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: submitting
                                        ? null
                                        : () => setModalState(
                                          () => numberOfChildren =
                                          (numberOfChildren + 1).clamp(0, 10),
                                    ),
                                    icon: const Icon(Icons.add_circle_outline),
                                  ),
                                ],
                              ),
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
                              text: submitting ? 'Submitting...' : 'Join waitlist',
                              onPressed: submitting ? () {} : submit,
                              backgroundColor: AppTheme.bookingButtonColor,
                              textColor: Colors.white,
                            ),
                            const SizedBox(height: 10),
                            TextButton(
                              onPressed: submitting ? null : () => Navigator.of(sheetCtx).pop(),
                              child: const Text('Cancel',
                                  style: TextStyle(fontFamily: 'CharlevoixPro')),
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
                        hoverBackgroundColor: const Color(0xFFFFA726),
                        textColor: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _InfoCard(
                icon: Icons.celebration_outlined,
                title: 'Upcoming Event',
                content: 'Grand opening event - 16 March 2026',
                subcontent: "Don't forget to register and join the party!",
                footer: Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: SizedBox(
                    width: 170,
                    child: NestPrimaryButton(
                      text: 'Join waitlist',
                      onPressed: () => _joinWaitlist(context),
                      backgroundColor: AppTheme.bookingButtonColor,
                      textColor: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const _InfoCard(
                icon: Icons.access_time_filled_rounded,
                title: 'Opening Hours',
                content: 'Mon - Fri: 8:00 AM - 6:00 PM',
                subcontent: 'Sat - Sun & Holidays: Closed',
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
                    SizedBox(
                      width: 210,
                      child: NestPrimaryButton(
                        text: 'Choose membership',
                        onPressed: () => _goMembership(context),
                        backgroundColor: const Color(0xFFFF5757),
                        textColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const _SectionTitle(title: 'About NEST'),
              const SizedBox(height: 12),
              _Card(
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
                        '✨ A quiet workspace\n'
                            '✨ Montessori-inspired childcare\n'
                            '✨ A supportive community\n'
                            '✨ A family café & classes\n',
                        style: TextStyle(
                          fontFamily: 'CharlevoixPro',
                          fontSize: 14,
                          color: AppTheme.darkText,
                          height: 1.6,
                        ),
                        textAlign: TextAlign.left,
                      ),
                    ),
                    const SizedBox(height: 10),
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
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        child: NestPrimaryButton(
          text: widget.text,
          onPressed: widget.onPressed,
          backgroundColor: _hovered ? widget.hoverBackgroundColor : widget.backgroundColor,
          textColor: widget.textColor,
        ),
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
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
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

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.content,
    required this.subcontent,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.secondaryText, size: 20),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'CharlevoixPro',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: const TextStyle(
              fontFamily: 'CharlevoixPro',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subcontent,
            style: const TextStyle(
              fontFamily: 'CharlevoixPro',
              fontSize: 14,
              color: AppTheme.secondaryText,
              height: 1.35,
            ),
          ),
          if (footer != null) footer!,
        ],
      ),
    );
  }
}
