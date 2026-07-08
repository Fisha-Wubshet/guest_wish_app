import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import '../../core/branch/branch_provider.dart';
import '../../core/locale/app_strings.dart';
import '../../core/locale/locale_provider.dart';
import '../../core/models/item.dart';
import '../../core/models/customer.dart';
import '../../core/auth/auth_state.dart';
import '../../core/utils/formatters.dart';
import '../../shared/widgets/eth_date_picker.dart';
import '../bookings/bookings_provider.dart';

class NewBookingScreen extends ConsumerStatefulWidget {
  const NewBookingScreen({super.key});

  @override
  ConsumerState<NewBookingScreen> createState() => _NewBookingScreenState();
}

class _NewBookingScreenState extends ConsumerState<NewBookingScreen> {
  final _pageCtrl = PageController();
  int _step = 0;

  // Step 0 – Dates
  DateTime? _startDate;
  DateTime? _endDate;

  // Step 1 – Items
  List<Item> _availableItems = [];
  bool _loadingItems = false;
  String _itemSearch = '';
  String? _selectedCategory;
  final List<_CartItem> _cart = [];

  // Step 2 – Customer
  final _phoneCtrl = TextEditingController();
  Timer? _debounce;
  List<Customer> _suggestions = [];
  bool _loadingCustomers = false;
  bool _hasSearched = false;
  Customer? _selectedCustomer;
  bool _showNewForm = false;
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _altPhoneCtrl = TextEditingController();
  bool _savingCustomer = false;

  // Step 3 – Payment
  final _totalCtrl = TextEditingController();
  final _advanceCtrl = TextEditingController();

  // Submit
  bool _submitting = false;

  @override
  void dispose() {
    _pageCtrl.dispose();
    _phoneCtrl.dispose();
    _debounce?.cancel();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _altPhoneCtrl.dispose();
    _totalCtrl.dispose();
    _advanceCtrl.dispose();
    super.dispose();
  }

  // ─── Computed ─────────────────────────────────────────────────────────────

  double get _days => (_startDate != null && _endDate != null)
      ? _endDate!.difference(_startDate!).inDays.clamp(1, 9999).toDouble()
      : 0;

  double get _cartTotal =>
      _cart.fold(0.0, (s, c) => s + c.item.pricePerDay * c.qty * _days);

  double get _balance =>
      (double.tryParse(_totalCtrl.text) ?? 0) -
      (double.tryParse(_advanceCtrl.text) ?? 0);

  List<String> get _categories {
    final cats = _availableItems
        .map((i) => i.categoryName ?? '')
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return cats;
  }

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
    return list;
  }

  // ─── Item fetch ───────────────────────────────────────────────────────────

  Future<void> _fetchItems() async {
    if (_startDate == null || _endDate == null) return;
    setState(() => _loadingItems = true);
    try {
      final branchId = ref.read(branchScopeProvider);
      final res = await ref.read(apiClientProvider).get(
        '/bookings/dashboard',
        params: {
          'pickupDate': toApiDate(_startDate!),
          'returnDate': toApiDate(_endDate!),
          if (branchId != null) 'branchId': branchId,
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
      setState(() {
        _availableItems = raw
            .map((e) => Item.fromJson(e as Map<String, dynamic>))
            .where((item) => item.available)
            .toList();
        _selectedCategory = null;
        _itemSearch = '';
      });
    } catch (_) {
    } finally {
      setState(() => _loadingItems = false);
    }
  }

  // ─── Cart ─────────────────────────────────────────────────────────────────

  void _addToCart(Item item) {
    setState(() {
      final i = _cart.indexWhere((c) => c.item.id == item.id);
      if (i >= 0) {
        final current = _cart[i].qty;
        if (current < item.availableUnits) {
          _cart[i] = _cart[i].copyWith(qty: current + 1);
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

  // ─── Customer search ──────────────────────────────────────────────────────

  void _onPhoneChanged(String v) {
    _debounce?.cancel();
    setState(() {
      _selectedCustomer = null;
      _showNewForm = false;
      _suggestions = [];
      _hasSearched = false;
    });
    if (v.length < 3) return;
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => _searchCustomers(v),
    );
  }

  Future<void> _searchCustomers(String q) async {
    setState(() => _loadingCustomers = true);
    try {
      final res = await ref
          .read(apiClientProvider)
          .get('/customers/autocomplete', params: {'q': q});
      final data = res.data;
      final List<dynamic> rawList = data is List
          ? data
          : (data['data'] as List<dynamic>? ?? []);
      setState(() {
        _suggestions = rawList
            .map((e) => Customer.fromJson(e as Map<String, dynamic>))
            .toList();
        _hasSearched = true;
      });
    } catch (_) {
      setState(() => _hasSearched = true);
    } finally {
      if (mounted) setState(() => _loadingCustomers = false);
    }
  }

  void _selectCustomer(Customer c) {
    setState(() {
      _selectedCustomer = c;
      _phoneCtrl.text = c.phoneNumber;
      _firstNameCtrl.text = c.firstName;
      _lastNameCtrl.text = c.lastName;
      _suggestions = [];
      _showNewForm = false;
    });
  }

  Future<void> _saveNewCustomer() async {
    if (_firstNameCtrl.text.trim().isEmpty || _phoneCtrl.text.trim().isEmpty) {
      _snack(S.newBooking.firstNamePhoneRequired);
      return;
    }
    setState(() => _savingCustomer = true);
    try {
      final res = await ref.read(apiClientProvider).post('/customers', data: {
        'firstName': _firstNameCtrl.text.trim(),
        'lastName': _lastNameCtrl.text.trim(),
        'phoneNumber': _phoneCtrl.text.trim(),
        if (_altPhoneCtrl.text.trim().isNotEmpty)
          'altPhoneNumber': _altPhoneCtrl.text.trim(),
      });
      final saved = Customer.fromJson(res.data as Map<String, dynamic>);
      setState(() {
        _selectedCustomer = saved;
        _showNewForm = false;
        _suggestions = [];
      });
    } catch (e) {
      if (mounted) {
        _snack('Failed to save customer: ${e.toString().split(':').last.trim()}');
      }
    } finally {
      if (mounted) setState(() => _savingCustomer = false);
    }
  }

  // ─── Navigation ───────────────────────────────────────────────────────────

  void _goTo(int step) {
    setState(() => _step = step);
    _pageCtrl.animateToPage(
      step,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _next() {
    switch (_step) {
      case 0:
        if (_startDate == null || _endDate == null) {
          _snack(S.newBooking.selectDates);
          return;
        }
        _fetchItems();
        _goTo(1);
      case 1:
        if (_cart.isEmpty) {
          _snack(S.newBooking.noItemsSelected);
          return;
        }
        _totalCtrl.text = _cartTotal.toStringAsFixed(2);
        _goTo(2);
      case 2:
        if (_selectedCustomer == null) {
          _snack(_showNewForm
              ? S.newBooking.saveBefore
              : S.newBooking.selectOrSave);
          return;
        }
        _goTo(3);
      case 3:
        if ((double.tryParse(_totalCtrl.text) ?? 0) <= 0) {
          _snack(S.newBooking.enterValidTotal);
          return;
        }
        if (_balance < 0) {
          _snack(S.newBooking.advanceExceedsTotal);
          return;
        }
        _goTo(4);
      case 4:
        _submit();
    }
  }

  void _back() {
    if (_step > 0) {
      _goTo(_step - 1);
    } else {
      context.pop();
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ─── Submit ───────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final c = _selectedCustomer!;
      final branchId = ref.read(branchScopeProvider);
      final res = await ref.read(apiClientProvider).post(
        '/bookings/create-invoice',
        data: {
          'firstName': c.firstName,
          'lastName': c.lastName,
          'phoneNumber': c.phoneNumber,
          if (c.altPhoneNumber?.isNotEmpty ?? false)
            'altPhoneNumber': c.altPhoneNumber,
          'bookingDate': toApiDate(_startDate!),
          'returnDate': toApiDate(_endDate!),
          'totalAgreedPrice': double.tryParse(_totalCtrl.text) ?? _cartTotal,
          'totalAdvancePayment': double.tryParse(_advanceCtrl.text) ?? 0,
          'customerId': c.id,
          'itemIds': _cart.expand((ci) => List.filled(ci.qty, ci.item.id)).toList(),
          'bypassCleaningGapItemIds': const <int>[],
          if (branchId != null) 'branchId': branchId,
        },
      );
      if (mounted) {
        final data = res.data;
        final ref2 = data is Map
            ? (data['invoiceNumber'] ?? data['invoice_number'] ?? '')
            : '';
        ref.read(bookingsProvider.notifier).load();
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ref2.toString().isNotEmpty
              ? '${S.newBooking.bookingCreated}: $ref2'
              : S.newBooking.bookingCreatedSuccess),
          backgroundColor: const Color(0xFF10B981),
          duration: const Duration(seconds: 4),
        ));
      }
    } catch (e) {
      if (mounted) {
        _snack('Failed: ${e.toString().split(':').last.trim()}');
        setState(() => _submitting = false);
      }
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    final itemLabel = ref.watch(authProvider).user?.itemLabel ?? 'Item';
    final branchState = ref.watch(branchProvider);
    final user = ref.watch(authProvider).user;
    final String? activeBranchName = user?.isShopAdmin == true
        ? branchState.activeBranch?.name
        : user?.branchName;

    final titles = [
      S.newBooking.titleDates,
      S.newBooking.titleItems,
      S.newBooking.titleCustomer,
      S.newBooking.payment,
      S.newBooking.stepReview,
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(titles[_step]),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: LinearProgressIndicator(
            value: (_step + 1) / 5,
            backgroundColor: const Color(0xFFF1F5F9),
            valueColor: const AlwaysStoppedAnimation(Color(0xFF7C3AED)),
          ),
        ),
      ),
      body: PageView(
        controller: _pageCtrl,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _StepDates(
            startDate: _startDate,
            endDate: _endDate,
            days: _days,
            branchName: activeBranchName,
            onStartPicked: (d) => setState(() {
              _startDate = d;
              if (_endDate != null && _endDate!.isBefore(d)) _endDate = null;
            }),
            onEndPicked: (d) => setState(() => _endDate = d),
          ),
          _StepItems(
            items: _filteredItems,
            loading: _loadingItems,
            cart: _cart,
            days: _days,
            cartTotal: _cartTotal,
            categories: _categories,
            selectedCategory: _selectedCategory,
            itemLabel: itemLabel,
            itemSearch: _itemSearch,
            onSearchChanged: (v) => setState(() => _itemSearch = v),
            onCategoryTap: (c) => setState(
              () => _selectedCategory = _selectedCategory == c ? null : c,
            ),
            onAdd: _addToCart,
            onRemove: _removeFromCart,
          ),
          _StepCustomer(
            phoneCtrl: _phoneCtrl,
            firstNameCtrl: _firstNameCtrl,
            lastNameCtrl: _lastNameCtrl,
            altPhoneCtrl: _altPhoneCtrl,
            suggestions: _suggestions,
            loadingCustomers: _loadingCustomers,
            hasSearched: _hasSearched,
            selectedCustomer: _selectedCustomer,
            showNewForm: _showNewForm,
            savingCustomer: _savingCustomer,
            onPhoneChanged: _onPhoneChanged,
            onSelectCustomer: _selectCustomer,
            onShowNewForm: () => setState(() => _showNewForm = true),
            onSaveNew: _saveNewCustomer,
            onClearCustomer: () => setState(() {
              _selectedCustomer = null;
              _phoneCtrl.clear();
              _firstNameCtrl.clear();
              _lastNameCtrl.clear();
              _altPhoneCtrl.clear();
              _suggestions = [];
              _hasSearched = false;
              _showNewForm = false;
            }),
          ),
          _StepPayment(
            totalCtrl: _totalCtrl,
            advanceCtrl: _advanceCtrl,
            cart: _cart,
            days: _days,
            cartTotal: _cartTotal,
            balance: _balance,
            onChanged: () => setState(() {}),
          ),
          _StepConfirm(
            startDate: _startDate,
            endDate: _endDate,
            cart: _cart,
            days: _days,
            customer: _selectedCustomer,
            total: double.tryParse(_totalCtrl.text) ?? 0,
            advance: double.tryParse(_advanceCtrl.text) ?? 0,
            balance: _balance,
          ),
        ],
      ),
      bottomNavigationBar: _BottomBar(
        step: _step,
        onBack: _back,
        onNext: _next,
        submitting: _submitting,
      ),
    );
  }
}

// ─── Data class ───────────────────────────────────────────────────────────────

class _CartItem {
  final Item item;
  final int qty;
  const _CartItem({required this.item, required this.qty});

  _CartItem copyWith({int? qty}) => _CartItem(item: item, qty: qty ?? this.qty);
}

// ─── Step 0: Dates ────────────────────────────────────────────────────────────

class _StepDates extends StatelessWidget {
  final DateTime? startDate;
  final DateTime? endDate;
  final double days;
  final String? branchName;
  final ValueChanged<DateTime> onStartPicked;
  final ValueChanged<DateTime> onEndPicked;

  const _StepDates({
    required this.startDate,
    required this.endDate,
    required this.days,
    required this.onStartPicked,
    required this.onEndPicked,
    this.branchName,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (branchName != null) ...[
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F3FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFDDD6FE)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.store_outlined,
                      size: 14, color: Color(0xFF7C3AED)),
                  const SizedBox(width: 6),
                  Text(
                    '${S.newBooking.branchLabel}: $branchName',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF7C3AED),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          _SectionHeader(
            icon: Icons.calendar_month_outlined,
            title: S.newBooking.whenIsRental,
            subtitle: S.newBooking.selectPickupReturn,
          ),
          const SizedBox(height: 24),
          _DateTile(
            label: S.newBooking.pickupDate,
            value: startDate,
            onPick: onStartPicked,
            firstDate: DateTime.now(),
          ),
          const SizedBox(height: 12),
          _DateTile(
            label: S.newBooking.returnDate,
            value: endDate,
            onPick: onEndPicked,
            firstDate: startDate ?? DateTime.now(),
          ),
          if (startDate != null && endDate != null) ...[
            const SizedBox(height: 20),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F3FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.schedule_outlined,
                      color: Color(0xFF7C3AED), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    '${days.toInt()} ${days.toInt() != 1 ? S.newBooking.daysRental : S.newBooking.dayRental}',
                    style: const TextStyle(
                      color: Color(0xFF7C3AED),
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Step 1: Items ────────────────────────────────────────────────────────────

class _StepItems extends StatelessWidget {
  final List<Item> items;
  final bool loading;
  final List<_CartItem> cart;
  final double days;
  final double cartTotal;
  final List<String> categories;
  final String? selectedCategory;
  final String itemLabel;
  final String itemSearch;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onCategoryTap;
  final ValueChanged<Item> onAdd;
  final ValueChanged<Item> onRemove;

  const _StepItems({
    required this.items,
    required this.loading,
    required this.cart,
    required this.days,
    required this.cartTotal,
    required this.categories,
    required this.selectedCategory,
    required this.itemLabel,
    required this.itemSearch,
    required this.onSearchChanged,
    required this.onCategoryTap,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              onChanged: onSearchChanged,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: S.newBooking.searchItemHint,
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
        // Category chips
        if (categories.isNotEmpty)
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) {
                final cat = categories[i];
                final active = selectedCategory == cat;
                return GestureDetector(
                  onTap: () => onCategoryTap(cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color:
                          active ? const Color(0xFF7C3AED) : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: active
                              ? const Color(0xFF7C3AED)
                                  .withValues(alpha: 0.25)
                              : Colors.black.withValues(alpha: 0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Text(
                      cat,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            active ? FontWeight.w700 : FontWeight.w500,
                        color: active
                            ? Colors.white
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 4),
        // Items list
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inventory_2_outlined,
                              size: 48, color: Colors.grey[300]),
                          const SizedBox(height: 12),
                          Text(
                            S.newBooking.noItemsAvailable,
                            style: TextStyle(
                                color: Colors.grey[500], fontSize: 14),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.fromLTRB(
                          16, 8, 16, cart.isNotEmpty ? 8 : 16),
                      itemCount: items.length,
                      itemBuilder: (ctx, i) {
                        final item = items[i];
                        final cartEntry = cart.where(
                            (c) => c.item.id == item.id).toList();
                        final cartQty =
                            cartEntry.isEmpty ? 0 : cartEntry.first.qty;
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
        // Sticky cart bar
        if (cart.isNotEmpty)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED),
              boxShadow: [
                BoxShadow(
                  color:
                      const Color(0xFF7C3AED).withValues(alpha: 0.3),
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
                    final totalUnits =
                        cart.fold(0, (s, c) => s + c.qty);
                    return Text(
                      '$totalUnits ${totalUnits != 1 ? S.items.units : S.items.unit}  ·  ${cart.length} ${cart.length != 1 ? S.newBooking.unitTypes : S.newBooking.unitType}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  }),
                ),
                const Spacer(),
                Text(
                  '${S.newBooking.expected}: ${formatCurrency(cartTotal)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ─── Step 2: Customer ─────────────────────────────────────────────────────────

class _StepCustomer extends StatelessWidget {
  final TextEditingController phoneCtrl;
  final TextEditingController firstNameCtrl;
  final TextEditingController lastNameCtrl;
  final TextEditingController altPhoneCtrl;
  final List<Customer> suggestions;
  final bool loadingCustomers;
  final bool hasSearched;
  final Customer? selectedCustomer;
  final bool showNewForm;
  final bool savingCustomer;
  final ValueChanged<String> onPhoneChanged;
  final ValueChanged<Customer> onSelectCustomer;
  final VoidCallback onShowNewForm;
  final VoidCallback onSaveNew;
  final VoidCallback onClearCustomer;

  const _StepCustomer({
    required this.phoneCtrl,
    required this.firstNameCtrl,
    required this.lastNameCtrl,
    required this.altPhoneCtrl,
    required this.suggestions,
    required this.loadingCustomers,
    required this.hasSearched,
    required this.selectedCustomer,
    required this.showNewForm,
    required this.savingCustomer,
    required this.onPhoneChanged,
    required this.onSelectCustomer,
    required this.onShowNewForm,
    required this.onSaveNew,
    required this.onClearCustomer,
  });

  @override
  Widget build(BuildContext context) {
    final showNoResults = hasSearched &&
        suggestions.isEmpty &&
        phoneCtrl.text.length >= 3 &&
        !loadingCustomers &&
        !showNewForm;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Icons.person_search_outlined,
            title: S.newBooking.whoIsRenting,
            subtitle: S.newBooking.searchByPhone,
          ),
          const SizedBox(height: 24),
          if (selectedCustomer != null) ...[
            _SelectedCustomerCard(
              customer: selectedCustomer!,
              onClear: onClearCustomer,
            ),
          ] else ...[
            // Phone field
            TextField(
              controller: phoneCtrl,
              onChanged: onPhoneChanged,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: S.newBooking.enterPhone,
                prefixIcon: loadingCustomers
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : const Icon(Icons.phone_outlined,
                        size: 20, color: Color(0xFF94A3B8)),
              ),
            ),
            // Autocomplete results
            if (suggestions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: suggestions.map((c) {
                    return ListTile(
                      onTap: () => onSelectCustomer(c),
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: const Color(0xFFF5F3FF),
                        child: Text(
                          c.initials,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF7C3AED),
                          ),
                        ),
                      ),
                      title: Text(
                        c.name,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        c.phoneNumber,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF94A3B8)),
                      ),
                      trailing: c.isBlacklisted
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                S.newBooking.blacklisted,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFFEF4444),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                          : null,
                      dense: true,
                    );
                  }).toList(),
                ),
              ),
            ],
            // No results
            if (showNoResults) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.info_outline,
                      size: 16, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 8),
                  const Text(
                    'No customer found',
                    style:
                        TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: onShowNewForm,
                    icon: const Icon(Icons.person_add_alt_1_outlined,
                        size: 16),
                    label: Text(S.newBooking.saveAsNewBtn),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF7C3AED),
                      textStyle: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
            // Save-as-new form
            if (showNewForm) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F3FF),
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: const Color(0xFFE9D5FF)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      S.newBooking.newCustomer,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF7C3AED),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: firstNameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        hintText: '${S.newBooking.firstName} *',
                        prefixIcon: const Icon(Icons.person_outline,
                            size: 18, color: Color(0xFF94A3B8)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: lastNameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        hintText: S.newBooking.lastName,
                        prefixIcon: const Icon(Icons.person_outline,
                            size: 18, color: Color(0xFF94A3B8)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: altPhoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        hintText: '${S.newBooking.altPhone} ${S.common.optional}',
                        prefixIcon: const Icon(Icons.phone_outlined,
                            size: 18, color: Color(0xFF94A3B8)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: savingCustomer ? null : onSaveNew,
                        child: savingCustomer
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : Text(S.newBooking.saveCustomer),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

// ─── Step 3: Payment ──────────────────────────────────────────────────────────

class _StepPayment extends StatelessWidget {
  final TextEditingController totalCtrl;
  final TextEditingController advanceCtrl;
  final List<_CartItem> cart;
  final double days;
  final double cartTotal;
  final double balance;
  final VoidCallback onChanged;

  const _StepPayment({
    required this.totalCtrl,
    required this.advanceCtrl,
    required this.cart,
    required this.days,
    required this.cartTotal,
    required this.balance,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Icons.payments_outlined,
            title: S.newBooking.paymentSetup,
            subtitle: S.newBooking.setAgreedPrice,
          ),
          const SizedBox(height: 24),
          // Price estimate breakdown
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                ...cart.map((c) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${c.item.name} ×${c.qty}',
                              style: const TextStyle(
                                  fontSize: 13, color: Color(0xFF334155)),
                            ),
                          ),
                          Text(
                            '${formatCurrency(c.item.pricePerDay)} × ${days.toInt()}d',
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    )),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(S.newBooking.expected,
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF64748B))),
                    Text(
                      formatCurrency(cartTotal),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF7C3AED),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: totalCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => onChanged(),
            decoration: InputDecoration(
              hintText: '${S.newBooking.totalAgreed} *',
              prefixIcon: const Icon(Icons.attach_money_rounded,
                  size: 20, color: Color(0xFF94A3B8)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: advanceCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => onChanged(),
            decoration: InputDecoration(
              hintText: S.newBooking.advancePayment,
              prefixIcon: const Icon(Icons.payments_outlined,
                  size: 20, color: Color(0xFF94A3B8)),
              errorText: balance < 0
                  ? S.newBooking.cannotExceed
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          // Balance due display
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
                Text(
                  S.newBooking.balanceDue,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                  ),
                ),
                Text(
                  formatCurrency(balance.abs()),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: balance < 0
                        ? const Color(0xFFF59E0B)
                        : balance == 0
                            ? const Color(0xFF10B981)
                            : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Step 4: Confirm ──────────────────────────────────────────────────────────

class _StepConfirm extends StatelessWidget {
  final DateTime? startDate;
  final DateTime? endDate;
  final List<_CartItem> cart;
  final double days;
  final Customer? customer;
  final double total;
  final double advance;
  final double balance;

  const _StepConfirm({
    required this.startDate,
    required this.endDate,
    required this.cart,
    required this.days,
    required this.customer,
    required this.total,
    required this.advance,
    required this.balance,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Icons.checklist_rounded,
            title: S.newBooking.reviewConfirm,
            subtitle: S.newBooking.doubleCheck,
          ),
          const SizedBox(height: 20),
          _ConfirmSection(
            title: S.newBooking.sectionDates,
            rows: [
              _ConfirmRow(S.newBooking.labelPickup,
                  startDate != null ? formatDateLong(toApiDate(startDate!)) : '—'),
              _ConfirmRow(S.newBooking.labelReturn,
                  endDate != null ? formatDateLong(toApiDate(endDate!)) : '—'),
              _ConfirmRow(S.newBooking.labelDuration, '${days.toInt()} ${S.newBooking.daysRental}'),
            ],
          ),
          const SizedBox(height: 12),
          _ConfirmSection(
            title: S.newBooking.sectionItems,
            rows: cart
                .map((c) =>
                    _ConfirmRow(c.item.name, '×${c.qty}  ·  ${c.item.code}'))
                .toList(),
          ),
          const SizedBox(height: 12),
          if (customer != null)
            _ConfirmSection(
              title: S.newBooking.sectionCustomer,
              rows: [
                _ConfirmRow(S.newBooking.labelName, customer!.name),
                _ConfirmRow(S.newBooking.labelPhone, customer!.phoneNumber),
                if (customer!.altPhoneNumber?.isNotEmpty ?? false)
                  _ConfirmRow(S.newBooking.labelAltPhone, customer!.altPhoneNumber!),
              ],
            ),
          const SizedBox(height: 12),
          _ConfirmSection(
            title: S.newBooking.sectionPayment,
            rows: [
              _ConfirmRow(S.newBooking.labelTotalAgreed, formatCurrency(total)),
              _ConfirmRow(S.newBooking.labelAdvance, formatCurrency(advance)),
              _ConfirmRow(S.newBooking.balanceDue, formatCurrency(balance)),
            ],
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

// ─── Bottom navigation bar ────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  final int step;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final bool submitting;

  const _BottomBar({
    required this.step,
    required this.onBack,
    required this.onNext,
    required this.submitting,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        children: [
          if (step > 0) ...[
            OutlinedButton(
              onPressed: onBack,
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
              child: Text(S.newBooking.back),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: ElevatedButton(
              onPressed: submitting ? null : onNext,
              child: submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : Text(step < 4 ? S.newBooking.continueBtn : S.newBooking.createBooking),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shared sub-widgets ───────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F3FF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFF7C3AED), size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  )),
              Text(subtitle,
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF94A3B8))),
            ],
          ),
        ),
      ],
    );
  }
}

class _DateTile extends ConsumerWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onPick;
  final DateTime firstDate;

  const _DateTile({
    required this.label,
    required this.value,
    required this.onPick,
    required this.firstDate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAmharic = ref.watch(localeProvider) == 'am';
    return GestureDetector(
      onTap: () async {
        if (isAmharic) {
          final iso = await showEthiopianDatePicker(
            context: context,
            initialDate: value != null ? toApiDate(value!) : null,
            firstDate: toApiDate(firstDate),
          );
          if (iso != null) onPick(DateTime.parse(iso));
        } else {
          final d = await showDatePicker(
            context: context,
            initialDate: value ?? firstDate,
            firstDate: firstDate,
            lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
          );
          if (d != null) onPick(d);
        }
      },
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: value != null
              ? const Color(0xFFF5F3FF)
              : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: value != null
                ? const Color(0xFFDDD6FE)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 20,
              color: value != null
                  ? const Color(0xFF7C3AED)
                  : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF94A3B8))),
                  const SizedBox(height: 2),
                  Text(
                    value != null
                        ? formatDateLong(toApiDate(value!))
                        : S.common.tapToSelect,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: value != null
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: value != null
                          ? const Color(0xFF0F172A)
                          : const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              value != null
                  ? Icons.check_circle_rounded
                  : Icons.chevron_right_rounded,
              color: value != null
                  ? const Color(0xFF7C3AED)
                  : const Color(0xFF94A3B8),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

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
    final atMax = cartQty >= item.availableUnits;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: inCart ? const Color(0xFFF5F3FF) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: inCart ? const Color(0xFF7C3AED) : const Color(0xFFF1F5F9),
          width: inCart ? 1.5 : 1,
        ),
        boxShadow: inCart
            ? [
                BoxShadow(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : const [],
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: inCart
                  ? const Color(0xFF7C3AED).withValues(alpha: 0.12)
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.inventory_2_outlined,
              size: 20,
              color: inCart ? const Color(0xFF7C3AED) : const Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(width: 12),
          // Name + meta
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      '${item.code}  ·  ${formatCurrency(item.pricePerDay)}/day',
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: item.availableUnits > 3
                            ? const Color(0xFFF0FDF4)
                            : const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${item.availableUnits} ${S.newBooking.unitsAvail}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: item.availableUnits > 3
                              ? const Color(0xFF16A34A)
                              : const Color(0xFFD97706),
                        ),
                      ),
                    ),
                  ],
                ),
                if (inCart && days > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${formatCurrency(item.pricePerDay * days)} × $cartQty = ${formatCurrency(item.pricePerDay * days * cartQty)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF7C3AED),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Qty controls
          if (inCart) ...[
            _QtyButton(
              icon: Icons.remove_rounded,
              onTap: onRemove,
              color: const Color(0xFF7C3AED),
            ),
            Container(
              width: 32,
              alignment: Alignment.center,
              child: Text(
                '$cartQty',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF7C3AED),
                ),
              ),
            ),
            _QtyButton(
              icon: Icons.add_rounded,
              onTap: atMax ? null : onAdd,
              color: atMax ? const Color(0xFFCBD5E1) : const Color(0xFF7C3AED),
            ),
          ] else ...[
            GestureDetector(
              onTap: onAdd,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  S.common.add,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color color;

  const _QtyButton({required this.icon, required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: onTap != null
              ? color.withValues(alpha: 0.12)
              : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}

class _SelectedCustomerCard extends StatelessWidget {
  final Customer customer;
  final VoidCallback onClear;

  const _SelectedCustomerCard(
      {required this.customer, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final blacklisted = customer.isBlacklisted;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            blacklisted ? const Color(0xFFFFF7ED) : const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: blacklisted
              ? const Color(0xFFFEDC99)
              : const Color(0xFFDDD6FE),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: blacklisted
                    ? const Color(0xFFFEE2E2)
                    : const Color(0xFFEDE9FE),
                child: Text(
                  customer.initials,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: blacklisted
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF7C3AED),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            customer.name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        if (blacklisted) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Blacklisted',
                              style: TextStyle(
                                fontSize: 10,
                                color: Color(0xFFEF4444),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      customer.phoneNumber,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded,
                    size: 18, color: Color(0xFF94A3B8)),
                onPressed: onClear,
              ),
            ],
          ),
          if (blacklisted) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 16, color: Color(0xFFEF4444)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This customer is blacklisted. Proceed with caution.',
                      style: TextStyle(
                          fontSize: 12, color: Color(0xFFB91C1C)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ConfirmSection extends StatelessWidget {
  final String title;
  final List<_ConfirmRow> rows;

  const _ConfirmSection({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF94A3B8),
                letterSpacing: 0.8,
              ),
            ),
          ),
          const Divider(height: 1),
          ...rows,
        ],
      ),
    );
  }
}

class _ConfirmRow extends StatelessWidget {
  final String label;
  final String value;

  const _ConfirmRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF94A3B8))),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
