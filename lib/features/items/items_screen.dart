import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_state.dart';
import '../../core/branch/branch_provider.dart';
import '../../core/locale/app_strings.dart';
import '../../core/locale/locale_provider.dart';
import '../../core/models/managed_item.dart';
import '../../core/utils/formatters.dart';

class ItemsScreen extends ConsumerStatefulWidget {
  const ItemsScreen({super.key});

  @override
  ConsumerState<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends ConsumerState<ItemsScreen> {
  List<ManagedItem> _items = [];
  List<Category> _categories = [];
  bool _loading = true;
  String? _error;
  int _page = 0;
  bool _hasMore = true;
  bool _loadingMore = false;
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
    _loadCategories();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200 &&
        _hasMore && !_loadingMore) {
      _loadMore();
    }
  }

  Map<String, dynamic> _branchParam() {
    final user = ref.read(authProvider).user;
    final scopeId = ref.read(branchScopeProvider);
    // SHOP_ADMIN: use actively selected branch; others: use own branch from JWT
    final branchId = scopeId ?? user?.branchId;
    if (branchId != null) return {'branchId': branchId};
    return {};
  }

  Future<void> _load({bool refresh = false}) async {
    if (refresh) setState(() { _page = 1; _hasMore = true; });
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ref.read(apiClientProvider).get(
        '/items/all',
        params: {..._branchParam(), 'page': 1, 'size': 20},
      );
      final data = res.data as Map<String, dynamic>;
      final rawList = data['data'] as List? ?? data['content'] as List? ?? [];
      final content = rawList
          .map((e) => ManagedItem.fromJson(e as Map<String, dynamic>))
          .toList();
      final currentPage = data['current_page'] as int? ?? 1;
      final lastPage = data['last_page'] as int? ?? 1;
      final isLast = data['last'] as bool? ?? (currentPage >= lastPage);
      setState(() {
        _items = content;
        _page = 2;
        _hasMore = !isLast;
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = S.items.noItems; _loading = false; });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final res = await ref.read(apiClientProvider).get(
        '/items/all',
        params: {..._branchParam(), 'page': _page, 'size': 20},
      );
      final data = res.data as Map<String, dynamic>;
      final rawList = data['data'] as List? ?? data['content'] as List? ?? [];
      final content = rawList
          .map((e) => ManagedItem.fromJson(e as Map<String, dynamic>))
          .toList();
      final currentPage = data['current_page'] as int? ?? _page;
      final lastPage = data['last_page'] as int? ?? _page;
      final isLast = data['last'] as bool? ?? (currentPage >= lastPage);
      setState(() {
        _items.addAll(content);
        _page++;
        _hasMore = !isLast;
        _loadingMore = false;
      });
    } catch (_) {
      setState(() => _loadingMore = false);
    }
  }

  Future<void> _loadCategories() async {
    try {
      final res = await ref.read(apiClientProvider).get('/categories');
      final list = res.data as List? ?? [];
      setState(() {
        _categories = list.map((e) => Category.fromJson(e as Map<String, dynamic>)).toList();
      });
    } catch (_) {}
  }

  bool get _canEdit {
    final user = ref.read(authProvider).user;
    return user?.isManager ?? false;
  }

  void _openCreate() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ItemSheet(
        api: ref.read(apiClientProvider),
        categories: _categories,
        branchParam: _branchParam(),
        onSaved: () => _load(refresh: true),
      ),
    );
  }

  void _openEdit(ManagedItem item) {
    if (!_canEdit) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ItemSheet(
        api: ref.read(apiClientProvider),
        categories: _categories,
        branchParam: _branchParam(),
        item: item,
        onSaved: () => _load(refresh: true),
      ),
    );
  }

  Future<void> _delete(ManagedItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(S.items.deleteItem),
        content: Text('${S.common.delete} "${item.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(S.common.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: Text(S.common.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(apiClientProvider).delete('/items/${item.id}');
      _load(refresh: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_err(e)), backgroundColor: const Color(0xFFEF4444)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    final canEdit = _canEdit;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        onRefresh: () => _load(refresh: true),
        child: CustomScrollView(
          controller: _scrollCtrl,
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF0F172A),
              title: Text(S.items.title, style: const TextStyle(fontWeight: FontWeight.w800)),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(height: 1, color: const Color(0xFFF1F5F9)),
              ),
            ),
            if (_loading)
              const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFCBD5E1)),
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: Color(0xFF94A3B8))),
                      const SizedBox(height: 16),
                      FilledButton(onPressed: () => _load(refresh: true), child: Text(S.common.retry)),
                    ],
                  ),
                ),
              )
            else if (_items.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.inventory_2_outlined, size: 64, color: Color(0xFFE2E8F0)),
                      const SizedBox(height: 16),
                      Text(S.items.noItemsYet, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8))),
                      if (canEdit) ...[
                        const SizedBox(height: 8),
                        Text(S.items.tapToAddItem, style: const TextStyle(color: Color(0xFFCBD5E1))),
                      ],
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      if (i == _items.length) {
                        return _loadingMore
                            ? const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                              )
                            : const SizedBox(height: 8);
                      }
                      return _ItemTile(
                        item: _items[i],
                        canEdit: canEdit,
                        onEdit: () => _openEdit(_items[i]),
                        onDelete: () => _delete(_items[i]),
                      );
                    },
                    childCount: _items.length + 1,
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              onPressed: _openCreate,
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: Text(S.items.addItem, style: const TextStyle(fontWeight: FontWeight.w700)),
            )
          : null,
    );
  }
}

// ─── Item Tile ────────────────────────────────────────────────────────────────

class _ItemTile extends StatelessWidget {
  final ManagedItem item;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ItemTile({
    required this.item,
    required this.canEdit,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: InkWell(
        onTap: canEdit ? onEdit : null,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Code avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    item.uniqueCode.length > 4 ? item.uniqueCode.substring(0, 4) : item.uniqueCode,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF7C3AED)),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (item.categoryName != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(item.categoryName!,
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF7C3AED))),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text('${item.quantity} ${item.quantity != 1 ? S.items.units : S.items.unit}',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                        if (item.hasCleaningGap) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.cleaning_services_outlined, size: 12, color: Color(0xFF94A3B8)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Price
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatCurrency(item.minPrice),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                  Text(S.items.perDay, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                ],
              ),
              if (canEdit) ...[
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, size: 18, color: Color(0xFF94A3B8)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onSelected: (v) {
                    if (v == 'edit') { onEdit(); } else if (v == 'delete') { onDelete(); }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'edit', child: Row(children: [const Icon(Icons.edit_outlined, size: 16), const SizedBox(width: 10), Text(S.common.edit)])),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFEF4444)), const SizedBox(width: 10), Text(S.common.delete, style: const TextStyle(color: Color(0xFFEF4444)))]),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Item Sheet (Create / Edit) ───────────────────────────────────────────────

class _ItemSheet extends StatefulWidget {
  final ApiClient api;
  final List<Category> categories;
  final Map<String, dynamic> branchParam;
  final ManagedItem? item;
  final VoidCallback onSaved;

  const _ItemSheet({
    required this.api,
    required this.categories,
    required this.branchParam,
    required this.onSaved,
    this.item,
  });

  @override
  State<_ItemSheet> createState() => _ItemSheetState();
}

class _ItemSheetState extends State<_ItemSheet> {
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  int? _categoryId;
  bool _cleaningGap = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    if (item != null) {
      _nameCtrl.text = item.name;
      _codeCtrl.text = item.uniqueCode;
      _priceCtrl.text = item.minPrice.toStringAsFixed(2);
      _qtyCtrl.text = item.quantity.toString();
      _descCtrl.text = item.description ?? '';
      _categoryId = widget.categories.any((c) => c.id == item.categoryId)
          ? item.categoryId
          : null;
      _cleaningGap = item.hasCleaningGap;
    } else {
      _qtyCtrl.text = '1';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _codeCtrl.dispose(); _priceCtrl.dispose();
    _qtyCtrl.dispose(); _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty || _codeCtrl.text.trim().isEmpty || _priceCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.items.nameCodePriceRequired), backgroundColor: const Color(0xFFEF4444)),
      );
      return;
    }
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      final body = {
        'name': _nameCtrl.text.trim(),
        'uniqueCode': _codeCtrl.text.trim(),
        'minPrice': double.tryParse(_priceCtrl.text) ?? 0,
        'quantity': int.tryParse(_qtyCtrl.text) ?? 1,
        'hasCleaningGap': _cleaningGap,
        if (_descCtrl.text.trim().isNotEmpty) 'description': _descCtrl.text.trim(),
        if (_categoryId != null) 'categoryId': _categoryId,
      };
      if (widget.item == null) {
        await widget.api.post('/items/add', data: {...body, ...widget.branchParam});
      } else {
        await widget.api.put('/items/${widget.item!.id}', data: {...body, ...widget.branchParam});
      }
      widget.onSaved();
      nav.pop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(_err(e)), backgroundColor: const Color(0xFFEF4444)));
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.item != null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                Text(isEdit ? S.items.editItem : S.items.addItem,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                const SizedBox(height: 20),
                _field(_nameCtrl, S.items.itemName, Icons.inventory_2_outlined),
                const SizedBox(height: 12),
                _field(_codeCtrl, S.items.uniqueCode, Icons.qr_code_rounded),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _field(_priceCtrl, S.items.minPriceDay, Icons.payments_outlined, isNumber: true)),
                  const SizedBox(width: 12),
                  Expanded(child: _field(_qtyCtrl, S.items.quantity, Icons.numbers_rounded, isNumber: true)),
                ]),
                const SizedBox(height: 12),
                DropdownButtonFormField<int?>(
                  value: _categoryId,
                  decoration: InputDecoration(
                    labelText: S.items.categoryOptional,
                    prefixIcon: const Icon(Icons.category_outlined, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  ),
                  items: [
                    DropdownMenuItem(value: null, child: Text(S.items.noCategory)),
                    ...widget.categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                  ],
                  onChanged: (v) => setState(() => _categoryId = v),
                ),
                const SizedBox(height: 12),
                _field(_descCtrl, S.items.descriptionOptional, Icons.notes_rounded, maxLines: 2),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () => setState(() => _cleaningGap = !_cleaningGap),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.cleaning_services_outlined, size: 20, color: Color(0xFF64748B)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(S.items.cleaningGap, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                              Text(S.items.cleaningGapSub, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                            ],
                          ),
                        ),
                        Switch(
                          value: _cleaningGap,
                          onChanged: (v) => setState(() => _cleaningGap = v),
                          activeColor: const Color(0xFF7C3AED),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _saving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(isEdit ? S.items.saveChanges : S.items.addItem,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon, {bool isNumber = false, int maxLines = 1}) =>
      TextField(
        controller: ctrl,
        keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      );
}

String _err(dynamic e) {
  try {
    final data = (e as dynamic).response?.data;
    if (data is Map) return (data['message'] ?? data['error'] ?? 'Error') as String;
    if (data is String) return data;
  } catch (_) {}
  return 'Something went wrong';
}
