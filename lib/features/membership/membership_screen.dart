import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import 'package:nest_app/widgets/nest_app_bar.dart';
import 'package:nest_app/widgets/nest_button.dart';

class MembershipScreen extends StatefulWidget {
  const MembershipScreen({super.key});

  @override
  State<MembershipScreen> createState() => _MembershipScreenState();
}

class _MembershipScreenState extends State<MembershipScreen> {
  final supabase = Supabase.instance.client;

  final PageController _pageController = PageController(viewportFraction: 0.85);
  int _currentPage = 0;
  bool _showContact = false;
  bool _isLoading = true;

  bool _purchasingPass = false;

  static const Color coral = Color(0xFFFF6B6B);
  static const Color grayText = Color(0xFF9E9E9E);
  static const Color creamBackground = Color(0xFFFDF8F3);
  static const Color secondaryText = Color(0xFF757575);

  static const Color _accentPink = Color(0xFFF87CC8);
  static const Color _actionYellow = Color(0xFFFFDE59);
  static const Color _samGreen = Color(0xFFB2E5D1);
  static const double _actionButtonHeight = 44;

  static const String _nestEmail = 'membership@nest-hamburg.de';
  static const String _nestPhone = '+49 40 1234 5678';
  static const String _nestWebsite = 'https://nestcoworkandplay.com/';

  List<Map<String, dynamic>> memberships = [];
  List<Map<String, dynamic>> passes = [];

  @override
  void initState() {
    super.initState();
    _loadMemberships();
    _pageController.addListener(() {
      final next = _pageController.page!.round();
      if (_currentPage != next) setState(() => _currentPage = next);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // Deep links
  Future<void> _launchUri(Uri uri) async {
    try {
      final ok = await canLaunchUrl(uri);
      if (!ok) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open link.'), backgroundColor: Colors.red),
        );
        return;
      }
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open link.'), backgroundColor: Colors.red),
      );
    }
  }

  Uri _mailtoUri(String email) => Uri(scheme: 'mailto', path: email);
  Uri _telUri(String phone) => Uri(scheme: 'tel', path: phone.replaceAll(' ', ''));
  Uri _webUri(String url) => Uri.parse(url);

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

  Future<void> _loadMemberships() async {
    try {
      final response = await supabase
          .from('memberships')
          .select('id, name, description_short, description_full, price_per_hour, bullet_points')
          .order('id');

      final List<Map<String, dynamic>> loaded = response.map<Map<String, dynamic>>((row) {
        return {
          'id': row['id'],
          'title': row['name'],
          'shortDesc': row['description_short'] ?? '',
          'fullDesc': row['description_full'] ?? row['description_short'] ?? '',
          'priceHour': (row['price_per_hour'] as num?)?.toStringAsFixed(2) ?? '',
          'color': _getColorForMembership(row['name']),
          'emoji': _getEmojiForMembership(row['name']),
          'image': _getImageForMembership(row['name']),
          'isPass': row['name'].toString().toLowerCase().contains('pass'),
          'bullets': row['bullet_points'] ?? [],
        };
      }).toList();

      final List<Map<String, dynamic>> membershipPlans = [];
      final List<Map<String, dynamic>> passProducts = [];

      const desiredOrder = [
        'full membership',
        'regular membership',
        'part-time membership',
        'light membership',
      ];

      for (var m in loaded) {
        final name = m['title'].toString().toLowerCase();
        if (desiredOrder.contains(name)) {
          membershipPlans.add(m);
        } else {
          passProducts.add(m);
        }
      }

      membershipPlans.sort((a, b) {
        return desiredOrder
            .indexOf(a['title'].toString().toLowerCase())
            .compareTo(desiredOrder.indexOf(b['title'].toString().toLowerCase()));
      });

      setState(() {
        memberships = membershipPlans;
        passes = passProducts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      // ignore: avoid_print
      print('Error loading memberships: $e');
    }
  }

  Color _getColorForMembership(String name) {
    switch (name.toLowerCase()) {
      case 'full membership':
        return const Color(0xFFFF5757);
      case 'regular membership':
        return const Color(0xFFF87CC8);
      case 'part-time membership':
        return const Color(0xFFFFBD59);
      case 'light membership':
        return const Color(0xFFFFDE59);
      case 'flexi-pass':
        return const Color(0xFFB2E5D1);
      case 'day pass':
        return const Color(0xFF444078);
      default:
        return const Color(0xFFFF5757);
    }
  }

  String _getImageForMembership(String name) {
    switch (name.toLowerCase()) {
      case 'full membership':
        return 'assets/images/carousel_full.png';
      case 'regular membership':
        return 'assets/images/carousel_regular.png';
      case 'part-time membership':
        return 'assets/images/carousel_parttime.png';
      case 'light membership':
        return 'assets/images/carousel_light.png';
      case 'flexi-pass':
        return 'assets/images/carousel_flexi.png';
      case 'day pass':
        return 'assets/images/carousel_day.png';
      default:
        return 'assets/images/carousel_full.png';
    }
  }

  String _getEmojiForMembership(String name) {
    switch (name.toLowerCase()) {
      case 'full membership':
        return '🚀';
      case 'regular membership':
        return '💼';
      case 'part-time membership':
        return '⏰';
      case 'light membership':
        return '✨';
      case 'flexi-pass':
        return '🎫';
      case 'day pass':
        return '📅';
      default:
        return '⭐';
    }
  }

  // Active membership helpers/dialog
  bool _isAlreadyActiveMembershipError(Object e) =>
      e.toString().toLowerCase().contains('already have an active membership');

  Future<Map<String, dynamic>?> _fetchMyMembership() async {
    final user = supabase.auth.currentUser;
    if (user == null) return null;

    try {
      final row = await supabase
          .from('users')
          .select('membership_status, membership_type, membership_start_date, membership_end_date')
          .eq('id', user.id)
          .maybeSingle();

      if (row == null) return null;
      return row as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
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
      default:
        if (t.isEmpty) return '';
        return t[0].toUpperCase() + t.substring(1);
    }
  }

  ButtonStyle _pillOutlinedStyle() => OutlinedButton.styleFrom(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
    side: BorderSide(color: Colors.black.withOpacity(0.18)),
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

  Future<void> _showAlreadyActiveMembershipDialog({Map<String, dynamic>? me}) async {
    if (!mounted) return;

    final type = _prettyMembershipType((me?['membership_type'] ?? '').toString());
    final status = (me?['membership_status'] ?? '').toString().trim().toLowerCase();

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
                'NEST Membership',
                style: TextStyle(
                  fontFamily: 'SweetAndSalty',
                  fontSize: 22,
                  color: AppTheme.darkText,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'You already have an active membership',
                style: TextStyle(
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
                  border: Border.all(color: Colors.black.withOpacity(0.08)),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                      color: Colors.black.withOpacity(0.06),
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
                          child: Text(_nestEmail,
                              style: TextStyle(fontFamily: 'CharlevoixPro', color: AppTheme.darkText)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: const [
                        Icon(Icons.phone, size: 18, color: AppTheme.darkText),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(_nestPhone,
                              style: TextStyle(fontFamily: 'CharlevoixPro', color: AppTheme.darkText)),
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
                              onPressed: () => _launchUri(_mailtoUri(_nestEmail)),
                              style: _pillFilledStyle(_actionYellow),
                              child: Text('Email', style: _pillTextStyle()),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SizedBox(
                            height: _actionButtonHeight,
                            child: ElevatedButton(
                              onPressed: () => _launchUri(_telUri(_nestPhone)),
                              style: _pillFilledStyle(_actionYellow),
                              child: Text('Call', style: _pillTextStyle()),
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
                        onPressed: () => _launchUri(_webUri(_nestWebsite)),
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

  // Pass purchase / membership request
  Future<void> _purchasePass(Map<String, dynamic> m) async {
    if (_purchasingPass) return;

    final user = supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in again.'), backgroundColor: Colors.red),
      );
      return;
    }

    final me = await _fetchMyMembership();
    if (((me?['membership_status'] ?? '').toString().toLowerCase()) == 'active') {
      await _showAlreadyActiveMembershipDialog(me: me);
      return;
    }

    setState(() => _purchasingPass = true);

    try {
      await supabase.rpc('purchase_pass', params: {'p_membership_id': m['id']});
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${m['title']} activated. Enjoy your Full Day booking!'),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not activate pass: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _purchasingPass = false);
    }
  }

  Future<void> _requestMembership({required Map<String, dynamic> m, required String promoCode}) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in again.'), backgroundColor: Colors.red),
      );
      return;
    }

    try {
      await supabase.rpc('request_membership', params: {
        'p_membership_id': m['id'],
        'p_promo_code': promoCode,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request sent! We will contact you soon to finalize your membership.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      if (_isAlreadyActiveMembershipError(e)) {
        final me = await _fetchMyMembership();
        await _showAlreadyActiveMembershipDialog(me: me);
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _showPassOffer(Map<String, dynamic> m) async {
    final me = await _fetchMyMembership();
    if (((me?['membership_status'] ?? '').toString().toLowerCase()) == 'active') {
      await _showAlreadyActiveMembershipDialog(me: me);
      return;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(m['emoji'], style: const TextStyle(fontSize: 40)),
              const SizedBox(height: 12),
              Text(m['title'] ?? '', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 12),
              Text(m['fullDesc'] ?? ''),
              const SizedBox(height: 12),
              const Text(
                'Passes are for Full Day bookings only.',
                style: TextStyle(color: secondaryText, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: NestPrimaryButton(
                      text: 'Not now',
                      onPressed: () {
                        if (_purchasingPass) return;
                        Navigator.pop(context);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: NestPrimaryButton(
                      text: _purchasingPass ? 'Activating…' : 'Get Pass',
                      onPressed: () async {
                        if (_purchasingPass) return;
                        Navigator.pop(context);
                        await _purchasePass(m);
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
  }

  Future<void> _showSubscriptionDialog(Map<String, dynamic> m) async {
    if (m['isPass'] == true) {
      await _showPassOffer(m);
      return;
    }

    final me = await _fetchMyMembership();
    if (((me?['membership_status'] ?? '').toString().toLowerCase()) == 'active') {
      await _showAlreadyActiveMembershipDialog(me: me);
      return;
    }

    final promo = TextEditingController();
    bool accepted = false;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Text(m['emoji'], style: const TextStyle(fontSize: 32)),
                const SizedBox(width: 12),
                Expanded(child: Text(m['title'] ?? '', style: Theme.of(context).textTheme.headlineMedium)),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ]),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: creamBackground, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(m['title'] ?? ''),
                    Text(
                      'From ${m['priceHour']} € / hour',
                      style: TextStyle(color: m['color'], fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: promo,
                decoration: InputDecoration(
                  labelText: 'Promo Code (optional)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: m['color'], width: 2),
                  ),
                ),
              ),
              Row(children: [
                Checkbox(value: accepted, onChanged: (v) => setDialogState(() => accepted = v ?? false)),
                const Expanded(child: Text('I accept the Terms')),
              ]),
              const SizedBox(height: 10),
              NestPrimaryButton(
                text: "Request membership",
                onPressed: () async {
                  if (!accepted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please accept the Terms to continue.'), backgroundColor: Colors.red),
                    );
                    return;
                  }
                  Navigator.pop(context);
                  await _requestMembership(m: m, promoCode: promo.text.trim());
                },
              )
            ]),
          ),
        ),
      ),
    );
  }

  // Sam section
  Widget _buildContactSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(color: coral.withOpacity(0.2), shape: BoxShape.circle),
              child: const Icon(Icons.person, color: coral, size: 40),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  'Hi, my name is Sam!',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  'Do you need help choosing?',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700, color: AppTheme.darkText),
                ),
                const SizedBox(height: 8),
                const Text(
                  'I am here to help find the perfect way of connecting with us! You are an employer and want to support your parent employees with a benefit that goes far beyond fruit baskets and “flexible hours.”? Discover our business options.',
                  style: TextStyle(color: secondaryText, height: 1.25),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: 200,
                  child: NestPrimaryButton(
                    text: _showContact ? "Hide Contact" : "Contact Me",
                    onPressed: () => setState(() => _showContact = !_showContact),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactInfo() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: coral.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: coral.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Row(children: const [
              Icon(Icons.email, color: coral, size: 20),
              SizedBox(width: 12),
              Text(_nestEmail),
            ]),
            const SizedBox(height: 12),
            Row(children: const [
              Icon(Icons.phone, color: coral, size: 20),
              SizedBox(width: 12),
              Text(_nestPhone),
            ]),
            const SizedBox(height: 14),

            // ✅ Buttons here now green (#B2E5D1)
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: _actionButtonHeight,
                    child: ElevatedButton(
                      onPressed: () => _launchUri(_mailtoUri(_nestEmail)),
                      style: _pillFilledStyle(_samGreen),
                      child: Text('Email', style: _pillTextStyle(color: Colors.white)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: _actionButtonHeight,
                    child: ElevatedButton(
                      onPressed: () => _launchUri(_telUri(_nestPhone)),
                      style: _pillFilledStyle(_samGreen),
                      child: Text('Call', style: _pillTextStyle(color: Colors.white)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Screen
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      // ✅ unified responsive logo AppBar
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
        child: Column(
          children: [
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: coral))
                  : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Text(
                            'Membership Options',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Find the perfect fit for your family',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: secondaryText),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // ✅ Shadow fix: padding + clipBehavior none
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: SizedBox(
                        height: 520,
                        child: PageView.builder(
                          clipBehavior: Clip.none,
                          controller: _pageController,
                          itemCount: memberships.length,
                          itemBuilder: (context, index) {
                            final m = memberships[index];
                            final active = index == _currentPage;
                            return AnimatedScale(
                              scale: active ? 1.0 : 0.9,
                              duration: const Duration(milliseconds: 300),
                              child: _buildMembershipCard(m, active),
                            );
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        memberships.length,
                            (index) => Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _currentPage == index ? 20 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _currentPage == index ? coral : grayText.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          Text(
                            'For those who thrive maximum flexibility',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Great for first-timers, testers and parents easing into a new routine',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: secondaryText),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // ✅ Shadow fix: padding + clipBehavior none
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: SizedBox(
                        height: 520,
                        child: PageView.builder(
                          clipBehavior: Clip.none,
                          controller: PageController(viewportFraction: 0.85),
                          itemCount: passes.length,
                          itemBuilder: (context, index) {
                            final m = passes[index];
                            return AnimatedScale(
                              scale: 1.0,
                              duration: const Duration(milliseconds: 300),
                              child: _buildMembershipCard(m, true),
                            );
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),
                    _buildContactSection(),
                    if (_showContact) _buildContactInfo(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMembershipCard(Map<String, dynamic> m, bool active) {
    final bool isPass = m['isPass'] == true;
    final String buttonText = isPass ? "Get Pass" : "Let's subscribe";

    Alignment imgAlign;
    switch (m['title'].toString().toLowerCase()) {
      case 'regular membership':
        imgAlign = const Alignment(-0.6, -0.5);
        break;
      case 'full membership':
        imgAlign = const Alignment(0.6, 0.1);
        break;
      case 'flexi-pass':
        imgAlign = const Alignment(-0.6, 0.0);
        break;
      case 'part-time membership':
        imgAlign = const Alignment(-0.4, 0.0);
        break;
      case 'day pass':
        imgAlign = const Alignment(0.0, -0.4);
        break;
      case 'light membership':
        imgAlign = Alignment.center;
        break;
      default:
        imgAlign = Alignment.center;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            blurRadius: active ? 15 : 6,
            color: Colors.black.withOpacity(active ? 0.12 : 0.06),
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            child: Image.asset(
              m['image'],
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
              alignment: imgAlign,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${m['emoji']}  ${m['title']}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  if ((m['priceHour'] ?? '').toString().isNotEmpty)
                    Text('From ${m['priceHour']} € / hour', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(m['shortDesc'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                  if (m['bullets'] != null && m['bullets'].isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: m['bullets'].map<Widget>((b) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("• ", style: TextStyle(fontSize: 15)),
                              Expanded(child: Text(b.toString(), style: const TextStyle(fontSize: 14))),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  const Spacer(),
                  Center(
                    child: SizedBox(
                      width: 200,
                      child: NestPrimaryButton(
                        text: buttonText,
                        onPressed: () async {
                          if (isPass) {
                            await _showPassOffer(m);
                          } else {
                            await _showSubscriptionDialog(m);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
