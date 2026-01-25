import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class MembershipScreen extends StatefulWidget {
  const MembershipScreen({super.key});

  @override
  State<MembershipScreen> createState() => _MembershipScreenState();
}

class _MembershipScreenState extends State<MembershipScreen> {
  final PageController _pageController = PageController(viewportFraction: 0.85);
  int _currentPage = 0;
  bool _showContact = false;

  // Color constants (in case AppTheme doesn't have them)
  static const Color coral = Color(0xFFFF6B6B);
  static const Color grayText = Color(0xFF9E9E9E);
  static const Color creamBackground = Color(0xFFFDF8F3);
  static const Color darkText = Color(0xFF2D2D2D);
  static const Color secondaryText = Color(0xFF757575);

  // Membership data
  final List<Map<String, dynamic>> memberships = [
    {
      'title': 'Full Membership',
      'emoji': '🚀',
      'color': coral,
      'price': '2,95',
      'shortDesc': 'Ultimate flexibility and freedom',
      'fullDesc': '''For parents who want the ultimate flexibility and the freedom to work whenever inspiration (or deadlines) call.

• Unlimited access Monday–Friday (9–18h)
• Ideal if you work hybrid or remote full-time
• Perfect for parents who want to stay close to their child every day
• Priority booking & maximum schedule freedom

Your workday, your way, without missing the important moments.'''
    },
    {
      'title': 'Regular Membership',
      'emoji': '💼',
      'color': Color(0xFFE91E63), // Magenta pink
      'price': '3,00',
      'shortDesc': 'Sweet spot between flexibility and structure',
      'fullDesc': '''The sweet spot between flexibility and structure.

• Up to 30 hours/week (choose your mix of mornings/afternoons)
• Great for rebuilding work hours without jumping straight into full-time care
• A balanced routine for parents who want more work time and daily closeness

Work more again without giving up proximity.'''
    },
    {
      'title': 'Part-Time Membership',
      'emoji': '⏰',
      'color': Color(0xFFFFD700), // Ichor gold
      'price': '3,79',
      'shortDesc': 'Easing back into work',
      'fullDesc': '''For parents easing back into work or supplementing shorter Kita days.

• Up to 18 hours/week
• Ideal for squeezing real focus work into a realistic window
• Designed for those who are tired of fitting full-time expectations into part-time hours

Make every hour count and still be there for the moments that matter.'''
    },
    {
      'title': 'Light Membership',
      'emoji': '✨',
      'color': Color(0xFFFFEB3B), // Bright yellow
      'price': '6,85',
      'shortDesc': 'Gentle entry into working with childcare nearby',
      'fullDesc': '''Your gentle entry into working with childcare nearby.

• Up to 6 hours/week
• Perfect for early babies, tentative transitions, and "let's try this" phases
• Great for parents who need predictable focus time without pressure

A small step that makes a big difference.'''
    },
    {
      'title': 'Flexi-Pass',
      'emoji': '🎫',
      'color': Color(0xFF00BCD4), // Cyan
      'price': '5,45',
      'shortDesc': 'Freedom without commitment',
      'fullDesc': '''Freedom without commitment.

• 10 full-day access credits, valid for 6 months
• Your go-to option during project sprints, exams, deadlines, or seasonal busy periods
• Zero pressure, just book when you need it

Flexibility you can actually feel.'''
    },
    {
      'title': 'Day Pass',
      'emoji': '📅',
      'color': Color(0xFF1565C0), // Dark blue
      'price': '4,25',
      'shortDesc': 'Perfect for one-off focus days',
      'fullDesc': '''Perfect for parents visiting, testing, or needing a one-off focus day.

• Access for one full day
• Great for guests, grandparents, and newcomers
• Available up to 3 times/person per year

Try NEST for a day and see what's possible.'''
    },
  ];

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {
      int next = _pageController.page!.round();
      if (_currentPage != next) {
        setState(() {
          _currentPage = next;
        });
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _showSubscriptionDialog(Map<String, dynamic> membership) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Text(
                    membership['emoji'],
                    style: const TextStyle(fontSize: 32),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      membership['title'],
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Price summary
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: creamBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Membership Summary',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          membership['title'],
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        Text(
                          'From ${membership['price']} € / hour',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: membership['color'],
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Payment options
              Text(
                'Payment Option',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              _buildPaymentOption('Monthly', true),
              const SizedBox(height: 8),
              _buildPaymentOption('Annual (10% discount)', false),
              const SizedBox(height: 24),

              // Terms and conditions
              Row(
                children: [
                  Checkbox(
                    value: false,
                    onChanged: (value) {
                      // TODO: Implement checkbox state
                    },
                    activeColor: coral,
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        // TODO: Show terms and conditions
                      },
                      child: Text(
                        'I accept the Terms and Conditions',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Subscribe button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // TODO: Implement subscription logic
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Subscription feature coming soon!'),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: membership['color'],
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Subscribe Now',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentOption(String title, bool selected) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
          color: selected ? coral : grayText.withOpacity(0.3),
          width: selected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
            color: selected ? coral : grayText,
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              color: selected ? darkText : secondaryText,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  void _showB2BDialog(String type) {
    final Map<String, dynamic> content = type == 'corporate'
        ? {
            'title': '🏢 Corporate Pass',
            'subtitle': 'Team-Sharing Pass',
            'description':
                '''For teams with several parents of babies or toddlers and where real-life disruptions can derail entire project timelines: sudden childcare breakdowns, Kita closures, sleep-deprived parents, or an employee drowning in guilt trying to "make it all work." The Corporate Pass gives them – and you – immediate relief. You regain consistency. They regain focus and satisfaction. Everyone wins.

The Corporate Pass includes:
• 10 full-day entries per month
• 9 hours of professional childcare per visit
• A quiet, fully equipped workspace for focused work
• Rotatable within a team or department
• Monthly or annual (discounted) contracts

Your Benefits:
• Supporting parents returning from parental leave
• Helping parents avoid moving to part-time roles
• Reducing last-minute absences due to childcare gaps
• Boosting efficiency during critical project phases
• Demonstrating genuine, lived family-friendliness

Impact: More focus. Less stress. Higher retention. A tangible benefit that parents actually value.

Only have one parent on your team who would benefit from NEST? Sponsor their membership, either in part or fully.''',
          }
        : {
            'title': '✈️ Expat Special',
            'subtitle': 'For Relocating Families',
            'description':
                '''For families of talent relocating to Hamburg with a young child. Moving to a new country is one of the biggest challenges for global hires, especially when:
• Kita allocation is unpredictable
• Final Kita placement may be across town
• Waiting times stretch from months to over a year
• Parents feel isolated without support or community

The NEST Expat Special solves all of this. It includes full-day NEST access and childcare, and can be shared between both parents in the same household.

Benefits for companies & relocation agencies:
• Faster onboarding for international talent
• Less stress for relocating families
• Reduced risk of drop-off before start date
• Smooth integration into Hamburg work & family life
• A bilingual (German/English) childcare environment
• Community for expat parents – critical for retention

This is not just childcare. It's a soft-landing package for global hires.''',
          };

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          content['title'],
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          content['subtitle'],
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: coral,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    content['description'],
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          height: 1.6,
                        ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Contact button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    // Scroll to contact section
                    // TODO: Implement scroll to contact
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: coral,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Contact Us for More Info',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: creamBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Top section - Logo, Headline, Subheadline (matching other screens)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // NEST logo
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: coral,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text(
                          'NEST',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Headline
                    Text(
                      'Membership Options',
                      style: Theme.of(context).textTheme.headlineLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),

                    // Subheadline
                    Text(
                      'Find the perfect fit for your family',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: secondaryText,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Membership carousel
              SizedBox(
                height: 400,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: memberships.length,
                  itemBuilder: (context, index) {
                    final membership = memberships[index];
                    final isActive = index == _currentPage;

                    return AnimatedScale(
                      scale: isActive ? 1.0 : 0.9,
                      duration: const Duration(milliseconds: 300),
                      child: _buildMembershipCard(membership, isActive),
                    );
                  },
                ),
              ),

              // Page indicators
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  memberships.length,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == index ? 24 : 8,
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

              // B2B Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section title
                    Text(
                      'Business Solutions',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Custom packages for companies and relocating families',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: secondaryText,
                          ),
                    ),
                    const SizedBox(height: 20),

                    // Corporate Pass card
                    _buildB2BCard(
                      title: 'Corporate Pass',
                      subtitle: 'Team-Sharing Pass',
                      icon: '🏢',
                      onTap: () => _showB2BDialog('corporate'),
                    ),
                    const SizedBox(height: 12),

                    // Expat Special card
                    _buildB2BCard(
                      title: 'Expat Special',
                      subtitle: 'For Relocating Families',
                      icon: '✈️',
                      onTap: () => _showB2BDialog('expat'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Contact section
              Padding(
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
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Staff image placeholder
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: coral.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person,
                          size: 40,
                          color: coral,
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Text and button
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Need help choosing?',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Our team is here to help',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _showContact = !_showContact;
                                });
                              },
                              icon: Icon(
                                _showContact ? Icons.close : Icons.contact_mail,
                                size: 18,
                              ),
                              label: Text(_showContact ? 'Hide Contact' : 'Contact Me'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: coral,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Contact info (when button is pressed)
              if (_showContact)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: coral.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: coral.withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.email, color: coral, size: 20),
                            const SizedBox(width: 12),
                            Text(
                              'membership@nest-hamburg.de',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.phone, color: coral, size: 20),
                            const SizedBox(width: 12),
                            Text(
                              '+49 40 1234 5678',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMembershipCard(Map<String, dynamic> membership, bool isActive) {
    return GestureDetector(
      onTap: () {
        // Show full description in a bottom sheet
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      membership['emoji'],
                      style: const TextStyle(fontSize: 32),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        membership['title'],
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(
                      membership['fullDesc'],
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            height: 1.6,
                          ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _showSubscriptionDialog(membership);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: membership['color'],
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Subscribe to this plan',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isActive ? 0.1 : 0.05),
              blurRadius: isActive ? 15 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image placeholder
            Container(
              height: 140,
              decoration: BoxDecoration(
                color: membership['color'].withOpacity(0.1),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Center(
                child: Text(
                  membership['emoji'],
                  style: const TextStyle(fontSize: 64),
                ),
              ),
            ),

            // Title with colored background
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: membership['color'],
              ),
              child: Text(
                membership['title'],
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            // Price
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'From ${membership['price']} € / hour',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: darkText,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    membership['shortDesc'],
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),

                  // Subscribe button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _showSubscriptionDialog(membership),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: membership['color'],
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Subscribe',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
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
  }

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
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Text(
              icon,
              style: const TextStyle(fontSize: 40),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: coral,
                        ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: grayText,
            ),
          ],
        ),
      ),
    );
  }
}

