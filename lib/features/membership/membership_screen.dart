import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import 'payment_screen.dart';
import 'package:nest_app/widgets/nest_button.dart';

class MembershipScreen extends StatefulWidget {
  const MembershipScreen({super.key});

  @override
  State<MembershipScreen> createState() => _MembershipScreenState();
}

class _MembershipScreenState extends State<MembershipScreen> {
  final PageController _pageController = PageController(viewportFraction: 0.85);
  int _currentPage = 0;
  bool _showContact = false;
  bool _isLoading = true;

  static const Color coral = Color(0xFFFF6B6B);
  static const Color grayText = Color(0xFF9E9E9E);
  static const Color creamBackground = Color(0xFFFDF8F3);
  static const Color darkText = Color(0xFF2D2D2D);
  static const Color secondaryText = Color(0xFF757575);

  List<Map<String, dynamic>> memberships = [];

  @override
  void initState() {
    super.initState();
    _loadMemberships();
    _pageController.addListener(() {
      final next = _pageController.page!.round();
      if (_currentPage != next) {
        setState(() => _currentPage = next);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // CALCULATE HOURLY PRICE
  double _calculateHourly(Map<String, dynamic> row) {
    final monthly = row['price_monthly'];
    final prepaid = row['price_prepaid'];
    final maxHours = row['max_hours_per_week'];

    if (monthly != null && maxHours != null && maxHours > 0) {
      return (monthly / 100) / (maxHours * 4);
    }
    if (prepaid != null) {
      final days = row['amount_days_access'] ?? 1;
      return (prepaid / 100) / days;
    }
    return 0.0;
  }

  // COLORS
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

  // IMAGES
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

  // EMOJIS
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

  // LOAD MEMBERSHIPS
  Future<void> _loadMemberships() async {
    try {
      final response = await Supabase.instance.client
          .from('memberships')
          .select()
          .order('id');

      final List<Map<String, dynamic>> loaded =
      response.map<Map<String, dynamic>>((row) {
        return {
          'id': row['id'],
          'title': row['name'],
          'shortDesc': row['description_short'] ?? '',
          'fullDesc': row['description_full'] ?? row['description_short'] ?? '',
          'priceHour': _calculateHourly(row).toStringAsFixed(2),
          'color': _getColorForMembership(row['name']),
          'emoji': _getEmojiForMembership(row['name']),
          'image': _getImageForMembership(row['name']),
          'isPass': row['name'].toLowerCase().contains('pass'),
        };
      }).toList();

      setState(() {
        memberships = loaded;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }
  // SHOW PASS OFFER
  void _showPassOffer(Map<String, dynamic> m) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(m['emoji'], style: const TextStyle(fontSize: 40)),
              const SizedBox(height: 12),
              Text(m['title'] ?? '',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 12),
              Text(m['fullDesc'] ?? ''),
              const SizedBox(height: 20),
              NestPrimaryButton(
                text: 'Mehr zum Angebot',
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // SUBSCRIPTION DIALOG
  void _showSubscriptionDialog(Map<String, dynamic> m) {
    if (m['isPass'] == true) {
      _showPassOffer(m);
      return;
    }

    final promo = TextEditingController();
    bool accepted = false;

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
                Expanded(
                    child: Text(
                      m['title'] ?? '',
                      style: Theme.of(context).textTheme.headlineMedium,
                    )),
                IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close)),
              ]),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: creamBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
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
                Checkbox(
                    value: accepted,
                    onChanged: (v) => setDialogState(() => accepted = v ?? false)),
                const Expanded(child: Text('I accept the Terms')),
              ]),
              const SizedBox(height: 10),
              NestPrimaryButton(
                text: 'Subscribe Now',
                onPressed: accepted
                    ? () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PaymentScreen(
                        membershipId: m['id'],
                        membershipName: m['title'],
                        membershipPrice: m['priceHour'],
                        membershipColor: m['color'],
                        promoCode: promo.text.trim(),
                      ),
                    ),
                  );
                }
                    : () {},
              )
            ]),
          ),
        ),
      ),
    );
  }

  // B2B SECTION
  Widget _buildB2BSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Business Solutions',
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text('Custom packages for companies and relocating families',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: secondaryText)),
        const SizedBox(height: 20),
        _buildB2BCard(
          title: 'Corporate Pass',
          subtitle: 'Team-Sharing Pass',
          icon: '🏢',
          onTap: () => _showB2BDialog('corporate'),
        ),
        const SizedBox(height: 12),
        _buildB2BCard(
          title: 'Expat Special',
          subtitle: 'For Relocating Families',
          icon: '✈️',
          onTap: () => _showB2BDialog('expat'),
        ),
      ]),
    );
  }

  // CONTACT SECTION
  Widget _buildContactSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: coral.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person, color: coral, size: 40),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Need help choosing?',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    const Text('Our team is here to help'),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => setState(() => _showContact = !_showContact),
                      icon: Icon(_showContact ? Icons.close : Icons.contact_mail),
                      label: Text(_showContact ? 'Hide Contact' : 'Contact Me'),
                      style:
                      ElevatedButton.styleFrom(backgroundColor: coral),
                    ),
                  ]),
            ),
          ],
        ),
      ),
    );
  }

  // CONTACT INFO
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
              Text('membership@nest-hamburg.de'),
            ]),
            const SizedBox(height: 12),
            Row(children: const [
              Icon(Icons.phone, color: coral, size: 20),
              SizedBox(width: 12),
              Text('+49 40 1234 5678'),
            ]),
          ],
        ),
      ),
    );
  }

  // B2B CARD
  Widget _buildB2BCard({
    required String title,
    required String subtitle,
    required String icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: grayText.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 40)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: coral)),
                  ]),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: grayText),
          ],
        ),
      ),
    );
  }

  // B2B DIALOG
  void _showB2BDialog(String type) {
    final data = type == 'corporate'
        ? {
      'title': '🏢 Corporate Pass',
      'subtitle': 'Team-Sharing Pass',
      'text': 'For teams with several parents...'
    }
        : {
      'title': '✈️ Expat Special',
      'subtitle': 'For Relocating Families',
      'text': 'For families relocating to Hamburg...'
    };

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(data['title'] ?? '',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(data['subtitle'] ?? '',
                style: const TextStyle(
                    color: coral, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            Text(data['text'] ?? ''),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: coral),
              child: const Text('Close', style: TextStyle(color: Colors.white)),
            )
          ]),
        ),
      ),
    );
  }
  // ---------------------------------------------------------
  // BUILD METHOD
  // ---------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: creamBackground,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: coral))
            : SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ---------------------------------------------------
              // HEADER
              // ---------------------------------------------------
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Image.asset('assets/images/nest_logo.png', height: 90),
                    const SizedBox(height: 20),
                    Text(
                      'Membership Options',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Find the perfect fit for your family',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: secondaryText),
                    ),
                  ],
                ),
              ),

              // ---------------------------------------------------
              // CAROUSEL (PageView)
              // ---------------------------------------------------
              SizedBox(
                height: 450,        // slightly taller for image alignment
                child: PageView.builder(
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

              const SizedBox(height: 20),

              // ---------------------------------------------------
              // PAGE INDICATOR DOTS
              // ---------------------------------------------------
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  memberships.length,
                      (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == index ? 20 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentPage == index
                          ? coral
                          : grayText.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // ---------------------------------------------------
              // B2B SECTION (VISIBLE AGAIN)
              // ---------------------------------------------------
              _buildB2BSection(),

              const SizedBox(height: 40),

              // ---------------------------------------------------
              // CONTACT SECTION
              // ---------------------------------------------------
              _buildContactSection(),

              if (_showContact) _buildContactInfo(),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
  // ---------------------------------------------------------
  // MEMBERSHIP CARD
  // ---------------------------------------------------------
  Widget _buildMembershipCard(Map<String, dynamic> m, bool active) {
    final bool isPass = m['isPass'];
    final String buttonText = isPass ? 'Zum Angebot' : 'Subscribe';

    // Fine-grained alignment per image
    Alignment imgAlign;
    switch (m['title'].toString().toLowerCase()) {
      case 'regular membership':
        imgAlign = const Alignment(-0.6, -0.5); // shift up & left (face visible)
        break;
      case 'full membership':
        imgAlign = const Alignment(0.6, 0.1);   // shift right
        break;
      case 'flexi-pass':
        imgAlign = const Alignment(-0.6, 0.0);  // shift left
        break;
      case 'part-time membership':
        imgAlign = const Alignment(-0.4, 0.0);  // slightly left
        break;
      case 'day pass':
        imgAlign = const Alignment(0.0, -0.4);  // shift upward
        break;
      case 'light membership':
        imgAlign = Alignment.center;            // already well-centered
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
        mainAxisSize: MainAxisSize.min,
        children: [
          // IMAGE HEADER
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

          // CARD CONTENT
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // TITLE
                Text(
                  '${m['emoji']}  ${m['title']}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                // PRICE
                Text(
                  'From ${m['priceHour']} € / hour',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 6),

                // SHORT DESC
                Text(
                  m['shortDesc'] ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 16),

                // BUTTON
                NestPrimaryButton(
                  text: buttonText,
                  onPressed: () => isPass
                      ? _showPassOffer(m)
                      : _showSubscriptionDialog(m),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
