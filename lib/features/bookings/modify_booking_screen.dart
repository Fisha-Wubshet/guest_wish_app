import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/branch/branch_provider.dart';
import '../../core/locale/locale_provider.dart';
import '../../core/models/booking.dart';
import '../../core/models/item.dart';
import '../../core/auth/auth_state.dart';
import '../../core/utils/formatters.dart';
import '../../shared/widgets/eth_date_picker.dart';
import 'bookings_provider.dart';

class ModifyBookingScreen extends ConsumerStatefulWidget {
  final Booking booking;
  const ModifyBookingScreen({super.key, required this.booking});

  @override
  ConsumerState<ModifyBookingScreen> createState() => _ModifyBookingScreenState();
}

class _ModifyBookingScreenState extends ConsumerState<ModifyBookingScreen> {
  final _pageCtrl = PageController();
  int _step = 0;

  // Step 0 – Dates
  late DateTime _startDate;
  late DateTime _endDate;

  // Step 0 – Items
  List<Item> _availableItems = [];
  bool _loadingItems = false;
  String _fetchError = '';
  String _itemSearch = '';
  String? _selectedCategory;
  late List<_CartItem> _cart;

  // Step 1 – Payment + Notes
  late final TextEditingController _totalCtrl;
  late final TextEditingController _advanceCtrl;
  final _notesCtrl = TextEditingController();

  bool _submitting = false;

  // Originals for diff
  late final DateTime _origStart;
  late final DateTime _origEnd;
  late final Map<int, ({String name, int qty})> _origItems;
  late final double _origTotal;
  late final double _origAdvance;

  @override
  void initState() {
    super.initState();
    final b = widget.booking;

    _origStart = DateTime.parse(b.startDate);
    _origEnd = DateTime.parse(b.endDate);
    _startDate = _origStart;
    _endDate = _origEnd;
    _origTotal = b.totalAmount;
    _origAdvance = b.amountPaid;

    // Group booking items by rental item ID
    final grouped = <int, ({String name, int qty, double ppd, String? cat, String code})>{};
    for (final bi in b.items) {
      final id = bi.item.id;
      if (grouped.containsKey(id)) {
        grouped[id] = (
          name: grouped[id]!.name,
          qty: grouped[id]!.qty + bi.quantity,
          ppd: grouped[id]!.ppd,
          cat: grouped[id]!.cat,
          code: grouped[id]!.code,
        );
      } else {
        grouped[id] = (
          name: bi.item.name,
          qty: bi.quantity,
          ppd: bi.pricePerDay,
          cat: bi.item.categoryName,
          code: bi.item.code,
        );
      }
    }

    _origItems = grouped.map((id, g) => MapEntry(id, (name: g.name, qty: g.qty)));

    // Pre-populate cart from current booking items (placeholder availableUnits)
    _cart = grouped.entries.map((e) => _CartItem(
      item: Item(
        id: e.key,
        name: e.value.name,
        code: e.value.code,
        pricePerDay: e.value.ppd,
        available: true,
        availableUnits: 9999,
        categoryName: e.value.cat,
      ),
      qty: e.value.qty,
    )).toList();

    _totalCtrl = TextEditingController(text: b.totalAmount.toStringAsFixed(2));
    _advanceCtrl = TextEditingController(text: b.amountPaid.toStringAsFixed(2));

    _fetchItems();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _totalCtrl.dispose();
    _advanceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  // ─── Computed ─────────────────────────────────────────────────────────────

  double get _days => _endDate.difference(_startDate).inDays.clamp(1, 9999).toDouble();

  double get _cartTotal =>
      _cart.fold(0.0, (s, c) => s + c.item.pricePerDay * c.qty * _days);

  double get _balance =>
      (double.tryParse(_totalCtrl.text) ?? 0) -
      (double.tryParse(_advanceCtrl.text) ?? 0);

  // Items in cart whose qty exceeds availability — must be resolved before saving
  List<_CartItem> get _conflictingItems =>
      _cart.where((c) => c.qty > c.item.availableUnits).toList();

  List<String> get _categories => _availableItems
      .map((i) => i.categoryName ?? '')
      .where((c) => c.isNotEmpty)
      .toSet()
      .toList()
    ..sort();

  // Show ALL items sorted: AVAILABLE → CLEANING/other → BOOKED (availableUnits==0)
  List<Item> get _filteredItems {
    var list = _availableItems;
    if (_selectedCategory != null) {
      list = list.where((i) => i.categoryName == _selectedCategory).toList();
    }
    if (_itemSearch.isNotEmpty) {
      final q = _itemSearch.toLowerCase();
      list = list
          .where((i) =>
              i.name.toLowerCase().contains(q) ||
              i.code.toLowerCase().contains(q))
          .toList();
    }
    // Sort: available first, then booked
    list = [...list]..sort((a, b) {
      final aOrder = a.availableUnits > 0 ? 0 : 1;
      final bOrder = b.availableUnits > 0 ? 0 : 1;
      return aOrder.compareTo(bOrder);
    });
    return list;
  }

  // ─── Fetch items ──────────────────────────────────────────────────────────
  //
  // Uses the booking's own branchId (same as Vue: booking.value.branch?.id).
  // Falls back to branchScopeProvider so shop-admins still work when branchId
  // isn't embedded in the booking response.
  // Always sends excludeBookingId so this booking's own items are freed up
  // and returned as available — matching exact Vue behaviour.

  Future<void> _fetchItems() async {
    setState(() { _loadingItems = true; _fetchError = ''; });
    try {
      // Use booking's own branch — mirrors Vue: booking.value.branch?.id
      final branchId = widget.booking.branchId ?? ref.read(branchScopeProvider);
      final res = await ref.read(apiClientProvider).get(
        '/bookings/dashboard',
        params: {
          'pickupDate': toApiDate(_startDate),
          'returnDate': toApiDate(_endDate),
          if (branchId != null) 'branchId': branchId,
          'excludeBookingId': widget.booking.id,
        },
      );
      final data = res.data;
      List<dynamic> raw;
      if (data is Map) {
        raw = (data['items'] ?? data['availableItems'] ?? data['data'] ?? [])
            as List<dynamic>;
      } else if (data is List) {
        raw = data;
      } else {
        raw = [];
      }

      // Parse ALL items — do NOT filter by available. Booked items must be
      // shown (greyed out) so the user can see conflicts, matching Vue.
      final items = raw
          .map((e) => Item.fromJson(e as Map<String, dynamic>))
          .toList();

      if (mounted) {
        setState(() {
          _availableItems = items;
          // Update cart entries with real availableUnits from the API.
          // Because excludeBookingId was sent, this booking's own items will
          // have their freed units reflected in availableUnits.
          for (int i = 0; i < _cart.length; i++) {
            final match = items.where((it) => it.id == _cart[i].item.id);
            if (match.isNotEmpty) {
              _cart[i] = _CartItem(item: match.first, qty: _cart[i].qty);
            }
            // If no match found, the cart item keeps its last known data.
          }
          _selectedCategory = null;
          _itemSearch = '';
        });
      }
    } catch (_) {
      if (mounted) setState(() => _fetchError = 'Failed to load items. Tap retry.');
    } finally {
      if (mounted) setState(() => _loadingItems = false);
    }
  }

  // ─── Cart mutations ───────────────────────────────────────────────────────

  void _addToCart(Item item) {
    // Mirror Vue addItem: guard against adding when nothing available
    if (item.availableUnits == 0) return;
    setState(() {
      final i = _cart.indexWhere((c) => c.item.id == item.id);
      if (i >= 0) {
        if (_cart[i].qty < item.availableUnits) {
          _cart[i] = _cart[i].copyWith(qty: _cart[i].qty + 1);
        }
      } else {
        _cart.add(_CartItem(item: item, qty: 1));
      }
    });
  }

  void _removeFromCart(Item item) {
    setState(() {
      final i = _cart.indexWhere((c) => c.item.id == item.id);
      if (i >= 0) {
        if (_cart[i].qty > 1) {
          _cart[i] = _cart[i].copyWith(qty: _cart[i].qty - 1);
        } else {
          _cart.removeAt(i);
        }
      }
    });
  }

  // ─── Navigation ───────────────────────────────────────────────────────────

  void _goTo(int step) {
    setState(() => _step = step);
    _pageCtrl.animateToPage(step,
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  void _next() {
    switch (_step) {
      case 0:
        if (_cart.isEmpty) {
          _snack('Add at least one item');
          return;
        }
        if (_conflictingItems.isNotEmpty) {
          _snack(
            'Remove items that exceed availability: '
            '${_conflictingItems.map((c) => c.item.code).join(', ')}',
          );
          return;
        }
        _goTo(1);
      case 1:
        if ((double.tryParse(_totalCtrl.text) ?? 0) <= 0) {
          _snack('Enter a valid total amount');
          return;
        }
        if (_balance < 0) {
          _snack('Advance payment cannot exceed the total agreed price');
          return;
        }
        _goTo(2);
      case 2:
        _submit();
    }
  }

  void _back() {
    if (_step > 0) _goTo(_step - 1);
    else Navigator.pop(context);
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  // ─── Submit ───────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    // Final guard matching Vue: check conflicts before sending
    if (_conflictingItems.isNotEmpty) {
      _snack('Remove items not available on the new dates before saving');
      _goTo(0);
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref.read(apiClientProvider).patch(
        '/bookings/${widget.booking.id}/change-items',
        data: {
          'dressIds': _cart
              .expand((c) => List.filled(c.qty, c.item.id))
              .toList(),
          'newTotalAgreedPrice':
              double.tryParse(_totalCtrl.text) ?? _origTotal,
          'newAdvancePaid':
              double.tryParse(_advanceCtrl.text) ?? _origAdvance,
          'newBookingDate': toApiDate(_startDate),
          'newReturnDate': toApiDate(_endDate),
          if (_notesCtrl.text.trim().isNotEmpty) 'notes': _notesCtrl.text.trim(),
        },
      );
      if (mounted) {
        ref.invalidate(bookingsProvider);
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        _snack('Failed: ${e.toString().split(':').last.trim()}');
        setState(() => _submitting = false);
      }
    }
  }

  // ─── Diff getters ─────────────────────────────────────────────────────────

  bool get _dateChanged => _startDate != _origStart || _endDate != _origEnd;

  Map<int, int> get _currentItemQty {
    final m = <int, int>{};
    for (final c in _cart) m[c.item.id] = c.qty;
    return m;
  }

  List<_DiffEntry> get _diffItems {
    final current = _currentItemQty;
    final allIds = {..._origItems.keys, ...current.keys};
    final result = <_DiffEntry>[];
    for (final id in allIds) {
      final origQty = _origItems[id]?.qty ?? 0;
      final newQty = current[id] ?? 0;
      if (newQty == origQty) continue;
      final name = _origItems[id]?.name ??
          _cart
              .firstWhere((c) => c.item.id == id,
                  orElse: () => _cart.first)
              .item
              .name;
      if (newQty > origQty) {
        result.add(_DiffEntry(name: name, qty: newQty - origQty, added: true));
      } else {
        result.add(_DiffEntry(name: name, qty: origQty - newQty, added: false));
      }
    }
    return result;
  }

  bool get _hasAnyChange {
    if (_dateChanged) return true;
    if (_diffItems.isNotEmpty) return true;
    if ((double.tryParse(_totalCtrl.text) ?? _origTotal) != _origTotal) return true;
    if ((double.tryParse(_advanceCtrl.text) ?? _origAdvance) != _origAdvance) return true;
    if (_notesCtrl.text.trim().isNotEmpty) return true;
    return false;
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final itemLabel = ref.watch(authProvider).user?.itemLabel ?? 'Item';
    const steps = ['Items & Dates', 'Payment', 'Review'];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(steps[_step]),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: LinearProgressIndicator(
            value: (_step + 1) / 3,
            backgroundColor: const Color(0xFFF1F5F9),
            valueColor: const AlwaysStoppedAnimation(Color(0xFF7C3AED)),
          ),
        ),
      ),
      body: PageView(
        controller: _pageCtrl,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _StepItemsAndDates(
            startDate: _startDate,
            endDate: _endDate,
            days: _days,
            loadingItems: _loadingItems,
            fetchError: _fetchError,
            items: _filteredItems,
            allItemCount: _availableItems.length,
            cart: _cart,
            conflictingItems: _conflictingItems,
            categories: _categories,
            selectedCategory: _selectedCategory,
            itemSearch: _itemSearch,
            itemLabel: itemLabel,
            onStartPicked: (d) {
              setState(() {
                _startDate = d;
                if (_endDate.isBefore(d)) _endDate = d;
              });
              _fetchItems();
            },
            onEndPicked: (d) {
              setState(() => _endDate = d);
              _fetchItems();
            },
            onRetry: _fetchItems,
            onSearchChanged: (v) => setState(() => _itemSearch = v),
            onCategoryTap: (c) => setState(
              () => _selectedCategory = _selectedCategory == c ? null : c,
            ),
            onAdd: _addToCart,
            onRemove: _removeFromCart,
          ),
          _StepPayment(
            totalCtrl: _totalCtrl,
            advanceCtrl: _advanceCtrl,
            notesCtrl: _notesCtrl,
            cart: _cart,
            days: _days,
            cartTotal: _cartTotal,
            balance: _balance,
            origTotal: _origTotal,
            origAdvance: _origAdvance,
            onChanged: () => setState(() {}),
          ),
          _StepReview(
            startDate: _startDate,
            endDate: _endDate,
            origStart: _origStart,
            origEnd: _origEnd,
            dateChanged: _dateChanged,
            diffItems: _diffItems,
            cart: _cart,
            newTotal: double.tryParse(_totalCtrl.text) ?? _origTotal,
            newAdvance: double.tryParse(_advanceCtrl.text) ?? _origAdvance,
            origTotal: _origTotal,
            origAdvance: _origAdvance,
            notes: _notesCtrl.text.trim(),
            hasAnyChange: _hasAnyChange,
            booking: widget.booking,
          ),
        ],
      ),
      bottomNavigationBar: _BottomBar(
        step: _step,
        submitting: _submitting,
        // Block step 0 when empty or conflicts; other steps always passable
        canProceed: _step == 0
            ? _cart.isNotEmpty && _conflictingItems.isEmpty
            : true,
        hasConflicts: _step == 0 && _conflictingItems.isNotEmpty,
        onBack: _back,
        onNext: _next,
      ),
    );
  }
}

// ─── Data ─────────────────────────────────────────────────────────────────────

class _CartItem {
  final Item item;
  final int qty;
  const _CartItem({required this.item, required this.qty});
  _CartItem copyWith({int? qty}) => _CartItem(item: item, qty: qty ?? this.qty);
}

class _DiffEntry {
  final String name;
  final int qty;
  final bool added;
  const _DiffEntry({required this.name, required this.qty, required this.added});
}

// ─── Step 0: Items & Dates ────────────────────────────────────────────────────

class _StepItemsAndDates extends StatelessWidget {
  final DateTime startDate;
  final DateTime endDate;
  final double days;
  final bool loadingItems;
  final String fetchError;
  final List<Item> items;
  final int allItemCount;
  final List<_CartItem> cart;
  final List<_CartItem> conflictingItems;
  final List<String> categories;
  final String? selectedCategory;
  final String itemSearch;
  final String itemLabel;
  final ValueChanged<DateTime> onStartPicked;
  final ValueChanged<DateTime> onEndPicked;
  final VoidCallback onRetry;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onCategoryTap;
  final ValueChanged<Item> onAdd;
  final ValueChanged<Item> onRemove;

  const _StepItemsAndDates({
    required this.startDate,
    required this.endDate,
    required this.days,
    required this.loadingItems,
    required this.fetchError,
    required this.items,
    required this.allItemCount,
    required this.cart,
    required this.conflictingItems,
    required this.categories,
    required this.selectedCategory,
    required this.itemSearch,
    required this.itemLabel,
    required this.onStartPicked,
    required this.onEndPicked,
    required this.onRetry,
    required this.onSearchChanged,
    required this.onCategoryTap,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Date bar ──
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 13, color: Color(0xFF7C3AED)),
                  const SizedBox(width: 6),
                  const Text('Rental Dates',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF7C3AED))),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F3FF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${days.toInt()} day${days != 1 ? 's' : ''}',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF7C3AED)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _DatePicker(
                      label: 'Pickup',
                      date: startDate,
                      firstDate: DateTime(2020),
                      onPick: onStartPicked,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.arrow_forward_rounded,
                        size: 16, color: Color(0xFF94A3B8)),
                  ),
                  Expanded(
                    child: _DatePicker(
                      label: 'Return',
                      date: endDate,
                      firstDate: startDate,
                      onPick: onEndPicked,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // ── Conflict banner (mirrors Vue conflict-banner) ──
        if (conflictingItems.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFFFFF7ED),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 16, color: Color(0xFFF59E0B)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Not available on these dates: '
                    '${conflictingItems.map((c) => c.item.code).join(', ')} '
                    '— remove them before saving.',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF92400E)),
                  ),
                ),
              ],
            ),
          ),

        // ── Search bar ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Container(
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2)),
              ],
            ),
            child: TextField(
              onChanged: onSearchChanged,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search $itemLabel by name or code…',
                hintStyle:
                    const TextStyle(color: Color(0xFFCBD5E1), fontSize: 14),
                prefixIcon: const Icon(Icons.search_rounded,
                    size: 18, color: Color(0xFFCBD5E1)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
        ),

        // ── Category chips ──
        if (categories.isNotEmpty)
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final cat = categories[i];
                final active = selectedCategory == cat;
                return GestureDetector(
                  onTap: () => onCategoryTap(cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: active ? const Color(0xFF7C3AED) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: active
                              ? const Color(0xFF7C3AED).withValues(alpha: 0.25)
                              : Colors.black.withValues(alpha: 0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Text(cat,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                active ? FontWeight.w700 : FontWeight.w500,
                            color: active
                                ? Colors.white
                                : const Color(0xFF64748B))),
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 4),

        // ── Item list ──
        Expanded(
          child: loadingItems
              ? const Center(
                  child: CircularProgressIndicator(
                      color: Color(0xFF7C3AED), strokeWidth: 2))
              : fetchError.isNotEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.wifi_off_rounded,
                              size: 40, color: Color(0xFFCBD5E1)),
                          const SizedBox(height: 12),
                          Text(fetchError,
                              style: const TextStyle(
                                  color: Color(0xFF94A3B8), fontSize: 13)),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: onRetry,
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : allItemCount == 0
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.inventory_2_outlined,
                                  size: 48, color: Colors.grey[300]),
                              const SizedBox(height: 12),
                              Text('No items found for this branch',
                                  style: TextStyle(
                                      color: Colors.grey[500], fontSize: 13)),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: onRetry,
                                icon: const Icon(Icons.refresh_rounded,
                                    size: 16),
                                label: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : items.isEmpty
                          ? const Center(
                              child: Text('No items match your search',
                                  style: TextStyle(
                                      color: Color(0xFF94A3B8), fontSize: 13)))
                          : ListView.builder(
                              padding: EdgeInsets.fromLTRB(
                                  16, 6, 16, cart.isNotEmpty ? 6 : 16),
                              itemCount: items.length,
                              itemBuilder: (_, i) {
                                final item = items[i];
                                final cartEntry = cart
                                    .where((c) => c.item.id == item.id)
                                    .toList();
                                final cartQty = cartEntry.isEmpty
                                    ? 0
                                    : cartEntry.first.qty;
                                return _ItemTile(
                                  item: item,
                                  days: days,
                                  cartQty: cartQty,
                                  onAdd: () => onAdd(item),
                                  onRemove: () => onRemove(item),
                                );
                              },
                            ),
        ),

        // ── Cart bar ──
        if (cart.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: conflictingItems.isNotEmpty
                  ? const Color(0xFFF59E0B)
                  : const Color(0xFF7C3AED),
              boxShadow: [
                BoxShadow(
                  color: (conflictingItems.isNotEmpty
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFF7C3AED))
                      .withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Builder(builder: (_) {
                    final totalUnits = cart.fold(0, (s, c) => s + c.qty);
                    return Text(
                      '$totalUnits unit${totalUnits != 1 ? 's' : ''}  ·  ${cart.length} type${cart.length != 1 ? 's' : ''}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    );
                  }),
                ),
                const Spacer(),
                if (conflictingItems.isNotEmpty)
                  const Text('⚠ Resolve conflicts',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700))
                else
                  Text(
                    'Est: ${formatCurrency(_CartCalc.total(cart, days))}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

// ─── Step 1: Payment + Notes ──────────────────────────────────────────────────

class _StepPayment extends StatelessWidget {
  final TextEditingController totalCtrl;
  final TextEditingController advanceCtrl;
  final TextEditingController notesCtrl;
  final List<_CartItem> cart;
  final double days;
  final double cartTotal;
  final double balance;
  final double origTotal;
  final double origAdvance;
  final VoidCallback onChanged;

  const _StepPayment({
    required this.totalCtrl,
    required this.advanceCtrl,
    required this.notesCtrl,
    required this.cart,
    required this.days,
    required this.cartTotal,
    required this.balance,
    required this.origTotal,
    required this.origAdvance,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final newTotal = double.tryParse(totalCtrl.text) ?? origTotal;
    final newAdv = double.tryParse(advanceCtrl.text) ?? origAdvance;
    final totalDelta = newTotal - origTotal;
    final advDelta = newAdv - origAdvance;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Estimate card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Selected Items',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF7C3AED))),
                const SizedBox(height: 10),
                ...cart.map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Expanded(
                              child: Text('${c.item.name} ×${c.qty}',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF334155)))),
                          Text(
                              '${formatCurrency(c.item.pricePerDay)} × ${days.toInt()}d',
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xFF94A3B8))),
                        ],
                      ),
                    )),
                const Divider(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Estimated',
                        style: TextStyle(
                            fontSize: 13, color: Color(0xFF64748B))),
                    Text(formatCurrency(cartTotal),
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF7C3AED))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _FieldWithDelta(
            controller: totalCtrl,
            label: 'Total Agreed Price',
            icon: Icons.attach_money_rounded,
            onChanged: onChanged,
            delta: totalDelta,
            origValue: origTotal,
          ),
          const SizedBox(height: 12),
          _FieldWithDelta(
            controller: advanceCtrl,
            label: 'Total Paid',
            icon: Icons.payments_outlined,
            onChanged: onChanged,
            delta: advDelta,
            origValue: origAdvance,
            errorText: balance < 0 ? 'Cannot exceed total agreed price' : null,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: balance < 0
                  ? const Color(0xFFFFF7ED)
                  : balance == 0
                      ? const Color(0xFFF0FDF4)
                      : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: balance < 0
                    ? const Color(0xFFFED7AA)
                    : balance == 0
                        ? const Color(0xFFBBF7D0)
                        : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Balance Due',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155))),
                Text(formatCurrency(balance.abs()),
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: balance < 0
                            ? const Color(0xFFF59E0B)
                            : balance == 0
                                ? const Color(0xFF10B981)
                                : const Color(0xFF0F172A))),
              ],
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: notesCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Notes / Reason for change (optional)',
              hintText: 'e.g. customer requested item swap',
              prefixIcon: const Icon(Icons.notes_rounded, size: 20),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Step 2: Review ───────────────────────────────────────────────────────────

class _StepReview extends StatelessWidget {
  final DateTime startDate;
  final DateTime endDate;
  final DateTime origStart;
  final DateTime origEnd;
  final bool dateChanged;
  final List<_DiffEntry> diffItems;
  final List<_CartItem> cart;
  final double newTotal;
  final double newAdvance;
  final double origTotal;
  final double origAdvance;
  final String notes;
  final bool hasAnyChange;
  final Booking booking;

  const _StepReview({
    required this.startDate,
    required this.endDate,
    required this.origStart,
    required this.origEnd,
    required this.dateChanged,
    required this.diffItems,
    required this.cart,
    required this.newTotal,
    required this.newAdvance,
    required this.origTotal,
    required this.origAdvance,
    required this.notes,
    required this.hasAnyChange,
    required this.booking,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: const Color(0xFFF5F3FF),
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.receipt_long_outlined,
                      color: Color(0xFF7C3AED), size: 22),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Modify Booking',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A))),
                    Text(booking.invoiceNumber,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF94A3B8))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (!hasAnyChange)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_outline_rounded,
                      color: Color(0xFF10B981), size: 18),
                  SizedBox(width: 8),
                  Text('No changes detected.',
                      style:
                          TextStyle(fontSize: 13, color: Color(0xFF166534))),
                ],
              ),
            )
          else ...[
            const Text('Changes Summary',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF94A3B8))),
            const SizedBox(height: 10),
            if (dateChanged)
              _ChangeRow(
                icon: Icons.calendar_today_outlined,
                label: 'Dates',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (startDate != origStart)
                      _DeltaText(
                          label: 'Pickup',
                          from: formatDate(toApiDate(origStart)),
                          to: formatDate(toApiDate(startDate))),
                    if (endDate != origEnd)
                      _DeltaText(
                          label: 'Return',
                          from: formatDate(toApiDate(origEnd)),
                          to: formatDate(toApiDate(endDate))),
                  ],
                ),
              ),
            if (diffItems.isNotEmpty) ...[
              const SizedBox(height: 8),
              _ChangeRow(
                icon: Icons.inventory_2_outlined,
                label: 'Items',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: diffItems
                      .map((d) => Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Row(
                              children: [
                                Icon(
                                  d.added
                                      ? Icons.add_circle_outline_rounded
                                      : Icons.remove_circle_outline_rounded,
                                  size: 14,
                                  color: d.added
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFFEF4444),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${d.added ? '+' : '-'}${d.qty}  ${d.name}',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: d.added
                                          ? const Color(0xFF166534)
                                          : const Color(0xFF991B1B)),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ),
            ],
            if (newTotal != origTotal || newAdvance != origAdvance) ...[
              const SizedBox(height: 8),
              _ChangeRow(
                icon: Icons.payments_outlined,
                label: 'Payment',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (newTotal != origTotal)
                      _DeltaText(
                          label: 'Total',
                          from: formatCurrency(origTotal),
                          to: formatCurrency(newTotal)),
                    if (newAdvance != origAdvance)
                      _DeltaText(
                          label: 'Paid',
                          from: formatCurrency(origAdvance),
                          to: formatCurrency(newAdvance)),
                  ],
                ),
              ),
            ],
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              _ChangeRow(
                icon: Icons.notes_rounded,
                label: 'Notes',
                child: Text(notes,
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF334155))),
              ),
            ],
          ],
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Final Selection',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF7C3AED))),
                const SizedBox(height: 10),
                ...cart.map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.circle,
                              size: 6, color: Color(0xFF7C3AED)),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text('${c.item.name} ×${c.qty}',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF334155)))),
                          Text(c.item.code,
                              style: const TextStyle(
                                  fontSize: 11, color: Color(0xFF94A3B8))),
                        ],
                      ),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Bottom bar ───────────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  final int step;
  final bool submitting;
  final bool canProceed;
  final bool hasConflicts;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const _BottomBar({
    required this.step,
    required this.submitting,
    required this.canProceed,
    required this.hasConflicts,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, pad + 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        children: [
          if (step > 0) ...[
            OutlinedButton(
              onPressed: submitting ? null : onBack,
              style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 14)),
              child: const Text('Back'),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: ElevatedButton(
              onPressed: (submitting || !canProceed) ? null : onNext,
              style: ElevatedButton.styleFrom(
                backgroundColor: hasConflicts
                    ? const Color(0xFFD97706)
                    : const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Text(
                      hasConflicts
                          ? 'Resolve conflicts first'
                          : step == 0
                              ? 'Continue to Payment'
                              : step == 1
                                  ? 'Review Changes'
                                  : 'Save Changes',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _DatePicker extends ConsumerWidget {
  final String label;
  final DateTime date;
  final DateTime firstDate;
  final ValueChanged<DateTime> onPick;

  const _DatePicker({
    required this.label,
    required this.date,
    required this.firstDate,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAmharic = ref.watch(localeProvider) == 'am';
    return GestureDetector(
      onTap: () async {
        if (isAmharic) {
          final iso = await showEthiopianDatePicker(
            context: context,
            initialDate: toApiDate(date),
            firstDate: toApiDate(firstDate),
          );
          if (iso != null) onPick(DateTime.parse(iso));
        } else {
          final d = await showDatePicker(
            context: context,
            initialDate: date,
            firstDate: firstDate,
            lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
          );
          if (d != null) onPick(d);
        }
      },
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F3FF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFDDD6FE)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 3),
            Text(
              formatDate(toApiDate(date)),
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A)),
            ),
          ],
        ),
      ),
    );
  }
}

// _ItemTile — mirrors Vue item card logic:
//   • availableUnits > 0, not in cart → normal white card, + enabled
//   • availableUnits = 0, not in cart → grey card, + disabled (Vue: return early in addItem)
//   • in cart, qty ≤ availableUnits → purple selected card
//   • in cart, qty > availableUnits → orange conflict card
class _ItemTile extends StatelessWidget {
  final Item item;
  final double days;
  final int cartQty;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const _ItemTile({
    required this.item,
    required this.days,
    required this.cartQty,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final inCart = cartQty > 0;
    final isUnavailable = item.availableUnits == 0;
    final isConflict = inCart && cartQty > item.availableUnits;
    final atMax = inCart && cartQty >= item.availableUnits;

    Color cardColor;
    Color borderColor;
    double borderWidth;
    if (isConflict) {
      cardColor = const Color(0xFFFFF7ED);
      borderColor = const Color(0xFFF59E0B);
      borderWidth = 1.5;
    } else if (inCart) {
      cardColor = const Color(0xFFF5F3FF);
      borderColor = const Color(0xFF7C3AED);
      borderWidth = 1.5;
    } else if (isUnavailable) {
      cardColor = const Color(0xFFF8FAFC);
      borderColor = const Color(0xFFE2E8F0);
      borderWidth = 1;
    } else {
      cardColor = Colors.white;
      borderColor = const Color(0xFFF1F5F9);
      borderWidth = 1;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: inCart && !isConflict
            ? [
                BoxShadow(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
                    blurRadius: 8)
              ]
            : [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 4)
              ],
      ),
      child: Row(
        children: [
          // Status strip (mirrors Vue ic-strip)
          Container(
            width: 4,
            height: 40,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: isConflict
                  ? const Color(0xFFF59E0B)
                  : inCart
                      ? const Color(0xFF7C3AED)
                      : isUnavailable
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF10B981),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isUnavailable && !inCart
                        ? const Color(0xFF94A3B8)
                        : isConflict
                            ? const Color(0xFF92400E)
                            : inCart
                                ? const Color(0xFF5B21B6)
                                : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(item.code,
                        style: TextStyle(
                            fontSize: 11,
                            color: isUnavailable && !inCart
                                ? const Color(0xFFCBD5E1)
                                : const Color(0xFF94A3B8))),
                    if (item.categoryName != null) ...[
                      Text(' · ',
                          style: TextStyle(
                              fontSize: 11,
                              color: isUnavailable && !inCart
                                  ? const Color(0xFFCBD5E1)
                                  : const Color(0xFF94A3B8))),
                      Text(item.categoryName!,
                          style: TextStyle(
                              fontSize: 11,
                              color: isUnavailable && !inCart
                                  ? const Color(0xFFCBD5E1)
                                  : const Color(0xFF94A3B8))),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                // Availability label (mirrors Vue avail-* classes)
                if (isConflict)
                  Text(
                    '⚠ Only ${item.availableUnits} available',
                    style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFF59E0B),
                        fontWeight: FontWeight.w600),
                  )
                else if (isUnavailable)
                  const Text('BOOKED',
                      style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFFEF4444),
                          fontWeight: FontWeight.w600))
                else if (item.pricePerDay > 0)
                  Text(
                    '${formatCurrency(item.pricePerDay)}/day',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF7C3AED)),
                  ),
              ],
            ),
          ),
          // Qty controls
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!inCart && !isUnavailable && item.availableUnits > 1)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text('${item.availableUnits} avail',
                      style: const TextStyle(
                          fontSize: 10, color: Color(0xFF94A3B8))),
                ),
              if (inCart) ...[
                _QtyBtn(icon: Icons.remove_rounded, onTap: onRemove),
                SizedBox(
                  width: 28,
                  child: Text(
                    '$cartQty',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: isConflict
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFF7C3AED)),
                  ),
                ),
                _QtyBtn(
                  icon: Icons.add_rounded,
                  onTap: atMax ? null : onAdd,
                  disabled: atMax,
                ),
              ] else
                // + only active when item has availability
                _QtyBtn(
                  icon: Icons.add_rounded,
                  onTap: isUnavailable ? null : onAdd,
                  disabled: isUnavailable,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool disabled;

  const _QtyBtn({required this.icon, this.onTap, this.disabled = false});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: disabled || onTap == null
                ? const Color(0xFFF1F5F9)
                : const Color(0xFF7C3AED),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(icon,
              size: 16,
              color: disabled || onTap == null
                  ? const Color(0xFFCBD5E1)
                  : Colors.white),
        ),
      );
}

class _FieldWithDelta extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final VoidCallback onChanged;
  final double delta;
  final double origValue;
  final String? errorText;

  const _FieldWithDelta({
    required this.controller,
    required this.label,
    required this.icon,
    required this.onChanged,
    required this.delta,
    required this.origValue,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final hasDelta = delta.abs() > 0.01;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => onChanged(),
          decoration: InputDecoration(
              labelText: label,
              prefixIcon: Icon(icon, size: 20),
              errorText: errorText),
        ),
        if (hasDelta)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 12),
            child: Row(
              children: [
                const Text('was ',
                    style: TextStyle(
                        fontSize: 11, color: Color(0xFF94A3B8))),
                Text(formatCurrency(origValue),
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF94A3B8))),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: delta > 0
                        ? const Color(0xFFF0FDF4)
                        : const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${delta > 0 ? '+' : ''}${formatCurrency(delta)}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: delta > 0
                          ? const Color(0xFF166534)
                          : const Color(0xFF92400E),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ChangeRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget child;

  const _ChangeRow(
      {required this.icon, required this.label, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                  color: const Color(0xFFF5F3FF),
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 16, color: const Color(0xFF7C3AED)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF94A3B8))),
                  const SizedBox(height: 4),
                  child,
                ],
              ),
            ),
          ],
        ),
      );
}

class _DeltaText extends StatelessWidget {
  final String label;
  final String from;
  final String to;

  const _DeltaText(
      {required this.label, required this.from, required this.to});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Row(
          children: [
            if (label.isNotEmpty)
              Text('$label: ',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF94A3B8))),
            Text(from,
                style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF94A3B8),
                    decoration: TextDecoration.lineThrough)),
            const Icon(Icons.arrow_forward_rounded,
                size: 12, color: Color(0xFF94A3B8)),
            Text(to,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A))),
          ],
        ),
      );
}

class _CartCalc {
  static double total(List<_CartItem> cart, double days) =>
      cart.fold(0.0, (s, c) => s + c.item.pricePerDay * c.qty * days);
}
