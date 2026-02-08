// lib/features/cafe/cafe_screen.dart

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nest_app/core/theme/app_theme.dart';
import 'package:nest_app/widgets/nest_app_bar.dart';
import 'package:nest_app/widgets/nest_button.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CafeScreen extends StatefulWidget {
  const CafeScreen({super.key});

  @override
  State<CafeScreen> createState() => _CafeScreenState();
}

class _CafeScreenState extends State<CafeScreen> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> categories = [];
  List<Map<String, dynamic>> items = [];

  int? selectedCategoryId;

  final Map<int, int> cart = {};
  bool _loading = true;

  final Set<String> _selectedAllergenFilters = {};

  double _cartFabScale = 1.0;
  Timer? _fabPulseTimer;

  final ScrollController _categoryScrollController = ScrollController();
  bool _showLeftArrow = false;
  bool _showRightArrow = false;

  @override
  void initState() {
    super.initState();
    _categoryScrollController.addListener(_updateCategoryArrows);
    _loadCafeData();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _updateCategoryArrows());
  }

  @override
  void dispose() {
    _fabPulseTimer?.cancel();
    _categoryScrollController.removeListener(_updateCategoryArrows);
    _categoryScrollController.dispose();
    super.dispose();
  }

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

  Future<void> _loadCafeData() async {
    try {
      final categoryResponse = await supabase
          .from('cafe_categories')
          .select()
          .order('display_order');
      final itemsResponse =
          await supabase.from('cafe_items').select().order('id');

      setState(() {
        categories = List<Map<String, dynamic>>.from(categoryResponse);
        items = List<Map<String, dynamic>>.from(itemsResponse);
        _loading = false;
      });

      WidgetsBinding.instance
          .addPostFrameCallback((_) => _updateCategoryArrows());
    } catch (e) {
      // ignore: avoid_print
      print('Error loading cafe data: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _updateCategoryArrows() {
    if (!_categoryScrollController.hasClients) return;

    final pos = _categoryScrollController.position;
    final canScroll = pos.maxScrollExtent > 0;

    final showLeft = canScroll && _categoryScrollController.offset > 2;
    final showRight =
        canScroll && _categoryScrollController.offset < pos.maxScrollExtent - 2;

    if (showLeft != _showLeftArrow || showRight != _showRightArrow) {
      setState(() {
        _showLeftArrow = showLeft;
        _showRightArrow = showRight;
      });
    }
  }

  void _scrollCategoriesBy(double delta) {
    if (!_categoryScrollController.hasClients) return;

    final pos = _categoryScrollController.position;
    final current = _categoryScrollController.offset;
    final target = (current + delta).clamp(0.0, pos.maxScrollExtent);

    _categoryScrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  List<Map<String, dynamic>> get _baseItems {
    if (selectedCategoryId == null) return items;
    return items.where((i) => i['category_id'] == selectedCategoryId).toList();
  }

  List<Map<String, dynamic>> get filteredItems {
    final base = _baseItems;
    if (_selectedAllergenFilters.isEmpty) return base;

    return base.where((item) {
      final allergens = _effectiveAllergensForItem(item).toSet();
      return allergens.intersection(_selectedAllergenFilters).isEmpty;
    }).toList();
  }

  double get cartTotal {
    double total = 0;
    for (final entry in cart.entries) {
      final item = items.firstWhere((i) => i['id'] == entry.key);
      total += (item['price'] as num) * entry.value;
    }
    return total;
  }

  void _pulseCartFab() {
    _fabPulseTimer?.cancel();
    setState(() => _cartFabScale = 1.08);
    _fabPulseTimer = Timer(const Duration(milliseconds: 160), () {
      if (!mounted) return;
      setState(() => _cartFabScale = 1.0);
    });
  }

  void _addToCart(int itemId) {
    setState(() {
      cart[itemId] = (cart[itemId] ?? 0) + 1;
    });
    HapticFeedback.lightImpact();
    _pulseCartFab();
  }

  void _removeFromCart(int itemId) {
    if (!cart.containsKey(itemId)) return;
    setState(() {
      cart[itemId] = cart[itemId]! - 1;
      if (cart[itemId]! <= 0) cart.remove(itemId);
    });
  }

  // ---------- HELPERS ----------

  num? _num(dynamic v) => v is num ? v : null;

  List<String> _stringListFromAny(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) {
      return raw
          .map((e) => e.toString().trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    if (raw is String) {
      final s = raw.trim();
      if (s.isEmpty || s == '0') return [];

      // JSON array stored as text
      if (s.startsWith('[') && s.endsWith(']')) {
        try {
          final decoded = jsonDecode(s);
          if (decoded is List) {
            return decoded
                .map((e) => e.toString().trim())
                .where((x) => x.isNotEmpty)
                .toList();
          }
        } catch (_) {
          // fall back
        }
      }

      // fallback: comma separated
      return s
          .split(',')
          .map((x) => x.trim())
          .where((x) => x.isNotEmpty)
          .toList();
    }
    return [];
  }

  String _normalizeTag(String s) =>
      s.trim().toLowerCase().replaceAll(' ', '_').replaceAll('-', '_');

  String _canonicalAllergenKey(String key) {
    final k = _normalizeTag(key);

    // common aliases -> canonical keys used in _allergenMeta
    if (k == 'wheat') return 'gluten';
    if (k == 'egg') return 'eggs';
    if (k == 'tree_nuts') return 'nuts';
    if (k == 'shellfish') return 'crustaceans';

    return k;
  }

  List<String> _parseAllergens(dynamic allergensRaw) {
    final set = <String>{};
    for (final a in _stringListFromAny(allergensRaw)) {
      final canon = _canonicalAllergenKey(a);
      if (_allergenMeta.containsKey(canon)) set.add(canon);
    }
    final known = set.toList()..sort();
    return known;
  }

  List<String> _effectiveAllergensForItem(Map<String, dynamic> item) {
    // ✅ Real allergens only (no fake/random fallback)
    return _parseAllergens(item['allergens']);
  }

  Map<String, num?> _effectiveNutritionForItem(Map<String, dynamic> item) {
    // Prefer per-portion fields; fallback to legacy fields where appropriate.
    final kcal =
        _num(item['energy_kcal_portion']) ?? _num(item['calories_kcal']);
    final kj = _num(item['energy_kj_portion']);

    final fat = _num(item['fat_g_portion']) ?? _num(item['fat_g']);
    final satFat = _num(item['sat_fat_g_portion']);
    final carbs = _num(item['carbs_g_portion']) ?? _num(item['carbs_g']);
    final sugars = _num(item['sugars_g_portion']);
    final protein = _num(item['protein_g_portion']) ?? _num(item['protein_g']);
    final salt = _num(item['salt_g_portion']);
    final fiber = _num(item['fiber_g_portion']);

    return {
      'kcal': kcal,
      'kj': kj,
      'fat_g': fat,
      'sat_fat_g': satFat,
      'carbs_g': carbs,
      'sugars_g': sugars,
      'protein_g': protein,
      'salt_g': salt,
      'fiber_g': fiber,
    };
  }

  static const Map<String, Map<String, String>> _allergenMeta = {
    // EU14 + a few safe aliases
    'milk': {'emoji': '🥛', 'label': 'Milk / Dairy'},
    'eggs': {'emoji': '🥚', 'label': 'Eggs'},
    'peanuts': {'emoji': '🥜', 'label': 'Peanuts'},
    'nuts': {'emoji': '🌰', 'label': 'Nuts'},
    'soy': {'emoji': '🌱', 'label': 'Soy'},
    'gluten': {'emoji': '🌾', 'label': 'Gluten / Wheat'},
    'sesame': {'emoji': '⚪', 'label': 'Sesame'},
    'fish': {'emoji': '🐟', 'label': 'Fish'},
    'crustaceans': {'emoji': '🦐', 'label': 'Crustaceans'},
    'molluscs': {'emoji': '🦪', 'label': 'Molluscs'},
    'celery': {'emoji': '🥬', 'label': 'Celery'},
    'mustard': {'emoji': '🌭', 'label': 'Mustard'},
    'lupin': {'emoji': '🌼', 'label': 'Lupin'},
    'sulphites': {'emoji': '🍷', 'label': 'Sulphites'},

    // legacy keys kept so older data doesn't break
    'shellfish': {'emoji': '🦐', 'label': 'Shellfish / Crustaceans'},
    'tree_nuts': {'emoji': '🌰', 'label': 'Tree nuts'},
  };

  void _showAllergenLegendSheet(List<String> allergensRaw) {
    final allergens = allergensRaw.map(_canonicalAllergenKey).toSet().toList()
      ..removeWhere((k) => !_allergenMeta.containsKey(k))
      ..sort();

    if (allergens.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) {
        return SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxHeight = constraints.maxHeight * 0.55;

              return ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Allergens',
                          style: TextStyle(
                            fontFamily: 'SweetAndSalty',
                            fontSize: 26,
                            color: AppTheme.darkText,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'What these icons mean:',
                          style: TextStyle(
                            fontFamily: 'CharlevoixPro',
                            fontSize: 14,
                            color: AppTheme.secondaryText,
                          ),
                        ),
                        const SizedBox(height: 14),
                        ...allergens.map((key) {
                          final meta = _allergenMeta[key]!;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              children: [
                                Text(meta['emoji']!,
                                    style: const TextStyle(fontSize: 18)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    meta['label']!,
                                    style: const TextStyle(
                                      fontFamily: 'CharlevoixPro',
                                      fontSize: 16,
                                      color: AppTheme.darkText,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
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
        );
      },
    );
  }

  void _showItemInfoSheet(Map<String, dynamic> item) {
    final allergens = _effectiveAllergensForItem(item);
    final nutrition = _effectiveNutritionForItem(item);

    // ✅ show ONLY the note when present
    final allergensNote = (item['allergens_note'] ?? '').toString().trim();

    final portionSize = (item['portion_size'] ?? '').toString().trim();

    bool hasVal(String key) => nutrition[key] != null;

    String fmt(num? v, {int decimals = 0}) {
      if (v == null) return '—';
      if (decimals == 0) return v.round().toString();

      final d = v.toDouble();
      final s = d.toStringAsFixed(decimals);

      // remove trailing .0 / .00 etc
      return s.replaceAll(RegExp(r'\.0+$'), '');
    }

    final nutritionRows = <Widget>[
      if (hasVal('kcal'))
        _nutritionRow('Calories', '${fmt(nutrition['kcal'])} kcal'),
      if (hasVal('kj')) _nutritionRow('Energy', '${fmt(nutrition['kj'])} kJ'),
      if (hasVal('protein_g'))
        _nutritionRow(
            'Protein', '${fmt(nutrition['protein_g'], decimals: 1)} g'),
      if (hasVal('carbs_g'))
        _nutritionRow('Carbs', '${fmt(nutrition['carbs_g'], decimals: 1)} g'),
      if (hasVal('sugars_g'))
        _nutritionRow('Sugars', '${fmt(nutrition['sugars_g'], decimals: 1)} g'),
      if (hasVal('fat_g'))
        _nutritionRow('Fat', '${fmt(nutrition['fat_g'], decimals: 1)} g'),
      if (hasVal('sat_fat_g'))
        _nutritionRow(
            'Saturated fat', '${fmt(nutrition['sat_fat_g'], decimals: 1)} g'),
      if (hasVal('fiber_g'))
        _nutritionRow('Fiber', '${fmt(nutrition['fiber_g'], decimals: 1)} g'),
      if (hasVal('salt_g'))
        _nutritionRow('Salt', '${fmt(nutrition['salt_g'], decimals: 2)} g'),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) {
        return SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxHeight = constraints.maxHeight * 0.65;

              return ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['name'] ?? 'Item',
                          style: const TextStyle(
                            fontFamily: 'SweetAndSalty',
                            fontSize: 26,
                            color: AppTheme.darkText,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Allergens',
                          style: TextStyle(
                            fontFamily: 'CharlevoixPro',
                            fontSize: 15,
                            color: AppTheme.secondaryText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // ✅ Requirement: ONLY show the note if present
                        if (allergensNote.isNotEmpty)
                          Text(
                            allergensNote,
                            style: const TextStyle(
                              fontFamily: 'CharlevoixPro',
                              fontSize: 14,
                              color: AppTheme.secondaryText,
                              height: 1.35,
                            ),
                          )
                        else if (allergens.isEmpty)
                          const Text(
                            'No allergen info available.',
                            style: TextStyle(
                              fontFamily: 'CharlevoixPro',
                              fontSize: 14,
                              color: AppTheme.secondaryText,
                            ),
                          )
                        else
                          ...allergens.map((key) {
                            final meta = _allergenMeta[key]!;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                children: [
                                  Text(meta['emoji']!,
                                      style: const TextStyle(fontSize: 18)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      meta['label']!,
                                      style: const TextStyle(
                                        fontFamily: 'CharlevoixPro',
                                        fontSize: 16,
                                        color: AppTheme.darkText,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),

                        const SizedBox(height: 14),
                        const Text(
                          'Nutrition (approx.)',
                          style: TextStyle(
                            fontFamily: 'CharlevoixPro',
                            fontSize: 15,
                            color: AppTheme.secondaryText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (portionSize.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Per portion: $portionSize',
                            style: const TextStyle(
                              fontFamily: 'CharlevoixPro',
                              fontSize: 13,
                              color: AppTheme.secondaryText,
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),

                        if (nutritionRows.isEmpty)
                          const Text(
                            'No nutrition info available.',
                            style: TextStyle(
                              fontFamily: 'CharlevoixPro',
                              fontSize: 14,
                              color: AppTheme.secondaryText,
                            ),
                          )
                        else
                          ...nutritionRows,

                        const SizedBox(height: 12),
                        const Text(
                          'If you have severe allergies, please ask our team.',
                          style: TextStyle(
                            fontFamily: 'CharlevoixPro',
                            fontSize: 13,
                            color: AppTheme.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _nutritionRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'CharlevoixPro',
                fontSize: 14,
                color: AppTheme.secondaryText,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'CharlevoixPro',
              fontSize: 14,
              color: AppTheme.darkText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _showCheckoutAllergenWarning() async {
    final allergenKeys = <String>{};

    for (final entry in cart.entries) {
      final itemId = entry.key;
      final item = items.firstWhere((i) => i['id'] == itemId, orElse: () => {});
      allergenKeys.addAll(_effectiveAllergensForItem(item));
    }

    final keys = allergenKeys.where(_allergenMeta.containsKey).toList()..sort();

    return (await showDialog<bool>(
          context: context,
          barrierDismissible: true,
          builder: (_) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              title: const Text(
                'Before you checkout',
                style: TextStyle(
                  fontFamily: 'SweetAndSalty',
                  fontSize: 26,
                  color: AppTheme.darkText,
                ),
              ),
              content: keys.isEmpty
                  ? const Text(
                      'If you have severe allergies, please ask our team before ordering.',
                      style: TextStyle(
                        fontFamily: 'CharlevoixPro',
                        fontSize: 15,
                        color: AppTheme.secondaryText,
                      ),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Your selected items may contain:',
                          style: TextStyle(
                            fontFamily: 'CharlevoixPro',
                            fontSize: 15,
                            color: AppTheme.secondaryText,
                          ),
                        ),
                        const SizedBox(height: 14),
                        ...keys.map((k) {
                          final meta = _allergenMeta[k]!;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                Text(meta['emoji']!,
                                    style: const TextStyle(fontSize: 18)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    meta['label']!,
                                    style: const TextStyle(
                                      fontFamily: 'CharlevoixPro',
                                      fontSize: 16,
                                      color: AppTheme.darkText,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 6),
                        const Text(
                          'If you have severe allergies, please ask our team.',
                          style: TextStyle(
                            fontFamily: 'CharlevoixPro',
                            fontSize: 13,
                            color: AppTheme.secondaryText,
                          ),
                        ),
                      ],
                    ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Review order',
                      style: TextStyle(fontFamily: 'CharlevoixPro')),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('I understand',
                      style: TextStyle(fontFamily: 'CharlevoixPro')),
                ),
              ],
            );
          },
        )) ??
        false;
  }

  Widget _crossedEmoji(String emoji, {required bool crossed}) {
    return SizedBox(
      width: 22,
      height: 22,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          if (crossed)
            Positioned.fill(
              child: CustomPaint(
                painter: _DiagonalSlashPainter(
                  color: Colors.white.withValues(alpha: 0.95),
                  strokeWidth: 2.2,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _filterChip({
    required Widget child,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppTheme.sageGreen : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                blurRadius: 6,
                offset: const Offset(0, 2),
                color: Colors.black.withValues(alpha: 0.08),
              )
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _ghostCircleButton({
    required IconData icon,
    required VoidCallback onPressed,
    String? tooltip,
  }) {
    return Opacity(
      opacity: 0.70,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              blurRadius: 6,
              offset: const Offset(0, 2),
              color: Colors.black.withValues(alpha: 0.08),
            )
          ],
        ),
        child: IconButton(
          padding: EdgeInsets.zero,
          iconSize: 22,
          onPressed: onPressed,
          tooltip: tooltip,
          icon: Icon(icon, color: AppTheme.secondaryText),
        ),
      ),
    );
  }

  Widget _cartFab() {
    return AnimatedScale(
      scale: _cartFabScale,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutBack,
      child: FloatingActionButton.extended(
        backgroundColor: AppTheme.bookingButtonColor,
        onPressed: () => _showCartModal(context),
        icon: const Icon(Icons.shopping_cart, color: Colors.white),
        label: Text(
          'Cart • €${cartTotal.toStringAsFixed(2)}',
          style: const TextStyle(fontFamily: 'CharlevoixPro'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.sageGreen),
        ),
      );
    }

    final bottomListPadding = cart.isEmpty ? 16.0 : 110.0;

    const allergenFilterKeys = <String>[
      'milk',
      'eggs',
      'gluten',
      'nuts',
      'soy',
      'sulphites',
    ];

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
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutBack,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(scale: animation, child: child),
          );
        },
        child: cart.isEmpty
            ? const SizedBox.shrink(key: ValueKey('fab-empty'))
            : KeyedSubtree(
                key: const ValueKey('fab-cart'),
                child: _cartFab(),
              ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 12),
            const Text(
              'Nest Café',
              style: TextStyle(
                fontFamily: 'SweetAndSalty',
                fontSize: 30,
                color: AppTheme.darkText,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Your cozy family café',
              style: TextStyle(
                fontFamily: 'CharlevoixPro',
                fontSize: 16,
                color: AppTheme.secondaryText,
              ),
            ),
            const SizedBox(height: 14),

            // ALLERGEN FILTER ROW
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 64,
                      child: ListView.separated(
                        clipBehavior: Clip.none,
                        scrollDirection: Axis.horizontal,
                        itemCount: allergenFilterKeys.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (_, index) {
                          final key = allergenFilterKeys[index];
                          final selected =
                              _selectedAllergenFilters.contains(key);
                          final meta = _allergenMeta[key]!;

                          return _filterChip(
                            selected: selected,
                            onTap: () {
                              setState(() {
                                if (selected) {
                                  _selectedAllergenFilters.remove(key);
                                } else {
                                  _selectedAllergenFilters.add(key);
                                }
                              });
                            },
                            child: _crossedEmoji(meta['emoji']!,
                                crossed: selected),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _ghostCircleButton(
                    icon: Icons.info_outline,
                    tooltip: 'Allergen info',
                    onPressed: () =>
                        _showAllergenLegendSheet(allergenFilterKeys),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // CATEGORY CHIPS with arrows
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  if (_showLeftArrow) ...[
                    _ghostCircleButton(
                      icon: Icons.chevron_left,
                      tooltip: 'Scroll left',
                      onPressed: () => _scrollCategoriesBy(-220),
                    ),
                    const SizedBox(width: 10),
                  ] else ...[
                    const SizedBox(width: 34),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: SizedBox(
                      height: 64,
                      child: ListView.separated(
                        controller: _categoryScrollController,
                        clipBehavior: Clip.none,
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        itemCount: categories.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, index) {
                          final c = categories[index];
                          final int id = c['id'] as int;
                          final bool selected = id == selectedCategoryId;

                          return GestureDetector(
                            onTap: () => setState(() {
                              selectedCategoryId = selected ? null : id;
                            }),
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: selected
                                    ? AppTheme.sageGreen
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                    color: Colors.black.withValues(alpha: 0.08),
                                  )
                                ],
                              ),
                              child: Row(
                                children: [
                                  Text(c['icon'] ?? '',
                                      style: const TextStyle(fontSize: 16)),
                                  const SizedBox(width: 6),
                                  Text(
                                    c['name'] ?? '',
                                    style: TextStyle(
                                      fontFamily: 'CharlevoixPro',
                                      color: selected
                                          ? Colors.white
                                          : AppTheme.darkText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (_showRightArrow)
                    _ghostCircleButton(
                      icon: Icons.chevron_right,
                      tooltip: 'Scroll right',
                      onPressed: () => _scrollCategoriesBy(220),
                    )
                  else
                    const SizedBox(width: 34),
                ],
              ),
            ),

            const SizedBox(height: 14),

            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.fromLTRB(16, 0, 16, bottomListPadding),
                itemCount: filteredItems.length,
                itemBuilder: (_, index) {
                  final item = filteredItems[index];
                  final count = cart[item['id']] ?? 0;
                  return _buildCafeItemCard(item, count);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCafeItemCard(Map<String, dynamic> item, int count) {
    final allergens = _effectiveAllergensForItem(item);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            blurRadius: 10,
            offset: const Offset(0, 4),
            color: Colors.black.withValues(alpha: 0.05),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 60,
            width: 60,
            decoration: BoxDecoration(
              color: AppTheme.creamBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                item['name'][0].toUpperCase(),
                style: const TextStyle(
                  fontFamily: 'SweetAndSalty',
                  fontSize: 22,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name'],
                  style: const TextStyle(
                    fontFamily: 'CharlevoixPro',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '€${(item['price'] as num).toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontFamily: 'CharlevoixPro',
                    color: AppTheme.secondaryText,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: allergens.map((key) {
                          final meta = _allergenMeta[key];
                          if (meta == null) return const SizedBox.shrink();
                          return Semantics(
                            label: meta['label']!,
                            child: Text(meta['emoji']!,
                                style: const TextStyle(fontSize: 16)),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () => _showItemInfoSheet(item),
                      borderRadius: BorderRadius.circular(999),
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(
                          Icons.info_outline,
                          size: 18,
                          color: AppTheme.secondaryText,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Row(
            children: [
              if (count > 0)
                IconButton(
                  onPressed: () => _removeFromCart(item['id']),
                  icon: const Icon(Icons.remove_circle, color: Colors.grey),
                ),
              if (count > 0)
                Text(
                  count.toString(),
                  style: const TextStyle(
                    fontFamily: 'CharlevoixPro',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              IconButton(
                onPressed: () => _addToCart(item['id']),
                icon: const Icon(
                  Icons.add_circle,
                  size: 30,
                  color: AppTheme.sageGreen,
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  void _showCartModal(BuildContext context) {
    // unchanged from your version
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, modalSetState) {
            final cartEntries = cart.entries.toList();

            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.75,
                child: Column(
                  children: [
                    const Text(
                      'Your Order',
                      style: TextStyle(
                        fontFamily: 'SweetAndSalty',
                        fontSize: 28,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: cartEntries.isEmpty
                          ? const Center(
                              child: Text(
                                'Your cart is empty.',
                                style: TextStyle(
                                  fontFamily: 'CharlevoixPro',
                                  color: AppTheme.secondaryText,
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: cartEntries.length,
                              itemBuilder: (_, index) {
                                final entry = cartEntries[index];
                                final itemId = entry.key;
                                final qty = entry.value;
                                final item =
                                    items.firstWhere((i) => i['id'] == itemId);

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 14),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item['name'],
                                              style: const TextStyle(
                                                fontFamily: 'CharlevoixPro',
                                                fontSize: 16,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '€${((item['price'] as num) * qty).toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                fontFamily: 'CharlevoixPro',
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () {
                                          _removeFromCart(itemId);
                                          modalSetState(() {});
                                        },
                                        icon: const Icon(Icons.remove_circle,
                                            color: Colors.grey),
                                      ),
                                      Text(
                                        qty.toString(),
                                        style: const TextStyle(
                                          fontFamily: 'CharlevoixPro',
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () {
                                          _addToCart(itemId);
                                          modalSetState(() {});
                                        },
                                        icon: const Icon(
                                          Icons.add_circle,
                                          size: 28,
                                          color: AppTheme.sageGreen,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 18),
                    NestPrimaryButton(
                      text: cartEntries.isEmpty
                          ? 'Back To Menu'
                          : 'Proceed to Checkout (€${cartTotal.toStringAsFixed(2)})',
                      onPressed: () async {
                        if (cartEntries.isEmpty) {
                          Navigator.pop(context);
                          return;
                        }

                        final ok = await _showCheckoutAllergenWarning();
                        if (!ok) return;

                        if (context.mounted) Navigator.pop(context);
                      },
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _DiagonalSlashPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  const _DiagonalSlashPainter({
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    const inset = 3.0;
    final start = Offset(inset, size.height - inset);
    final end = Offset(size.width - inset, inset);

    canvas.drawLine(start, end, paint);
  }

  @override
  bool shouldRepaint(covariant _DiagonalSlashPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
  }
}
