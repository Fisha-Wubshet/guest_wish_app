import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_state.dart';
import '../../core/branch/branch_provider.dart';
import '../../core/locale/app_strings.dart';
import '../../core/locale/locale_provider.dart';
import '../../core/models/managed_item.dart';

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  List<Category> _categories = [];
  bool _loading = true;
  String? _error;

  Map<String, dynamic> _branchParam() {
    final user = ref.read(authProvider).user;
    final scopeId = ref.read(branchScopeProvider);
    final branchId = scopeId ?? user?.branchId;
    if (branchId != null) return {'branchId': branchId};
    return {};
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ref.read(apiClientProvider).get('/categories', params: _branchParam());
      final raw = res.data;
      final list = (raw is Map
          ? (raw['data'] ?? raw['content'] ?? raw['categories'] ?? [])
          : raw) as List<dynamic>;
      if (mounted) setState(() { _categories = list.map((e) => Category.fromJson(e as Map<String, dynamic>)).toList(); });
    } catch (e) {
      if (mounted) setState(() { _error = _catErr(e); });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  Future<void> _showAddSheet() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CategorySheet(api: ref.read(apiClientProvider), branchParam: _branchParam()),
    );
    if (result == true) _load();
  }

  Future<void> _showEditSheet(Category cat) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CategorySheet(api: ref.read(apiClientProvider), editing: cat, branchParam: _branchParam()),
    );
    if (result == true) _load();
  }

  Future<void> _delete(Category cat) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(S.items.deleteCategory),
        content: Text('${S.common.delete} "${cat.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(S.common.cancel)),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: Text(S.common.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bp = _branchParam();
      final branchId = bp['branchId'];
      final path = branchId != null
          ? '/categories/${cat.id}?branchId=$branchId'
          : '/categories/${cat.id}';
      await ref.read(apiClientProvider).delete(path);
      messenger.showSnackBar(
        SnackBar(content: Text('"${cat.name}" deleted'), backgroundColor: const Color(0xFF10B981)),
      );
      _load();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(_catErr(e)), backgroundColor: const Color(0xFFEF4444)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    final user = ref.watch(authProvider).user;
    final canEdit = user?.isManager ?? false;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(S.nav.categories),
        centerTitle: false,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFF1F5F9)),
        ),
      ),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              onPressed: _showAddSheet,
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: Text(S.items.addCategory),
            )
          : null,
      body: _buildBody(canEdit),
    );
  }

  Widget _buildBody(bool canEdit) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED)));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFCBD5E1)),
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Color(0xFF94A3B8))),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _load,
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF7C3AED)),
              child: Text(S.common.retry),
            ),
          ],
        ),
      );
    }

    if (_categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.category_outlined, size: 36, color: Color(0xFF7C3AED)),
            ),
            const SizedBox(height: 16),
            Text(S.items.noCategoriesYet, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
            const SizedBox(height: 4),
            Text(S.items.tapToAddCategory, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(refresh: true),
      color: const Color(0xFF7C3AED),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: _categories.length,
        itemBuilder: (_, i) => _CategoryTile(
          category: _categories[i],
          canEdit: canEdit,
          onEdit: () => _showEditSheet(_categories[i]),
          onDelete: () => _delete(_categories[i]),
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final Category category;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CategoryTile({
    required this.category,
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
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              category.name.isNotEmpty ? category.name[0].toUpperCase() : '?',
              style: const TextStyle(
                color: Color(0xFF7C3AED),
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
        ),
        title: Text(
          category.name,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
        ),
        subtitle: Text(
          'ID: ${category.id}',
          style: const TextStyle(fontSize: 12, color: Color(0xFFCBD5E1)),
        ),
        trailing: canEdit
            ? PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF94A3B8)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (v) {
                  if (v == 'edit') onEdit();
                  if (v == 'delete') onDelete();
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'edit', child: Row(children: [const Icon(Icons.edit_outlined, size: 18), const SizedBox(width: 10), Text(S.common.edit)])),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                      const SizedBox(width: 10),
                      Text(S.common.delete, style: const TextStyle(color: Color(0xFFEF4444))),
                    ]),
                  ),
                ],
              )
            : null,
      ),
    );
  }
}

class _CategorySheet extends StatefulWidget {
  final ApiClient api;
  final Category? editing;
  final Map<String, dynamic> branchParam;

  const _CategorySheet({required this.api, required this.branchParam, this.editing});

  @override
  State<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends State<_CategorySheet> {
  final _nameCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.editing != null) _nameCtrl.text = widget.editing!.name;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() { _saving = true; _error = null; });
    try {
      final body = {'name': _nameCtrl.text.trim(), ...widget.branchParam};
      if (widget.editing != null) {
        await widget.api.put('/categories/${widget.editing!.id}', data: body);
      } else {
        await widget.api.post('/categories', data: body);
      }
      nav.pop(true);
    } catch (e) {
      setState(() { _error = _catErr(e); _saving = false; });
      messenger.showSnackBar(SnackBar(content: Text(_catErr(e)), backgroundColor: const Color(0xFFEF4444)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.editing != null;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 8, 24, 24 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            isEdit ? S.items.editCategory : S.items.newCategory,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 20),
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(10)),
              child: Text(_error!, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13)),
            ),
            const SizedBox(height: 12),
          ],
          Form(
            key: _formKey,
            child: TextFormField(
              controller: _nameCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: _inputDec(S.items.categoryName, Icons.category_outlined),
              validator: (v) => (v == null || v.trim().isEmpty) ? S.items.nameRequired : null,
              onFieldSubmitted: (_) => _save(),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(isEdit ? S.items.saveChanges : S.items.createCategory,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

InputDecoration _inputDec(String label, IconData icon) => InputDecoration(
  labelText: label,
  prefixIcon: Icon(icon, size: 20, color: const Color(0xFF94A3B8)),
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 2)),
  errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFEF4444))),
  focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFEF4444), width: 2)),
  filled: true,
  fillColor: const Color(0xFFF8FAFC),
  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
);

String _catErr(dynamic e) {
  try {
    final data = (e as dynamic).response?.data;
    if (data is Map) return (data['message'] ?? data['error'] ?? 'Error') as String;
    if (data is String) return data;
  } catch (_) {}
  return 'Something went wrong';
}
