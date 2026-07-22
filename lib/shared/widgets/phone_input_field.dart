import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/utils/countries.dart';

/// Combined country picker + digits input. Emits the normalized E.164 phone
/// number and the currently selected country dial code via [onChanged].
class PhoneInputField extends StatefulWidget {
  final String? initialDigits;
  final String initialCountryDial;
  final String? Function(String? normalized)? validator;
  final void Function(String digits, String countryDial, String? normalized)? onChanged;
  final void Function()? onSubmitted;
  final String? hint;
  final bool enabled;

  const PhoneInputField({
    super.key,
    this.initialDigits,
    this.initialCountryDial = '+251',
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.hint,
    this.enabled = true,
  });

  @override
  State<PhoneInputField> createState() => PhoneInputFieldState();
}

class PhoneInputFieldState extends State<PhoneInputField> {
  late TextEditingController _digitsCtrl;
  late Country _country;

  String get normalized =>
      normalizePhone(_digitsCtrl.text, countryDial: _country.dial) ?? '';
  String get countryDial => _country.dial;

  @override
  void initState() {
    super.initState();
    _digitsCtrl = TextEditingController(text: widget.initialDigits ?? '');
    _country = findCountryByDial(widget.initialCountryDial);
  }

  @override
  void dispose() {
    _digitsCtrl.dispose();
    super.dispose();
  }

  void _emit() {
    widget.onChanged?.call(_digitsCtrl.text, _country.dial, normalizePhone(_digitsCtrl.text, countryDial: _country.dial));
  }

  Future<void> _pickCountry() async {
    if (!widget.enabled) return;
    final chosen = await showModalBottomSheet<Country>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _CountryPickerSheet(),
    );
    if (chosen != null) {
      setState(() => _country = chosen);
      _emit();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      initialValue: normalized,
      validator: (_) => widget.validator?.call(normalized),
      builder: (state) {
        final borderColor = state.hasError
            ? const Color(0xFFEF4444)
            : const Color(0xFFE2E8F0);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: borderColor),
                borderRadius: BorderRadius.circular(12),
                color: widget.enabled ? Colors.white : const Color(0xFFF8FAFC),
              ),
              child: Row(
                children: [
                  InkWell(
                    onTap: _pickCountry,
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_country.flag, style: const TextStyle(fontSize: 20)),
                          const SizedBox(width: 6),
                          Text(
                            _country.dial,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_drop_down, size: 20, color: Color(0xFF64748B)),
                        ],
                      ),
                    ),
                  ),
                  Container(width: 1, height: 28, color: const Color(0xFFE2E8F0)),
                  Expanded(
                    child: TextField(
                      controller: _digitsCtrl,
                      enabled: widget.enabled,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d\s\-\+\(\)]'))],
                      textInputAction: TextInputAction.next,
                      onChanged: (_) { state.didChange(normalized); _emit(); },
                      onSubmitted: (_) => widget.onSubmitted?.call(),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        hintText: widget.hint ?? '912 345 678',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 12),
                child: Text(state.errorText!, style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12)),
              ),
          ],
        );
      },
    );
  }
}

class _CountryPickerSheet extends StatefulWidget {
  const _CountryPickerSheet();
  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final filtered = q.isEmpty
        ? kCountries
        : kCountries.where((c) =>
              c.name.toLowerCase().contains(q)
              || c.code.toLowerCase().contains(q)
              || c.dial.contains(q)).toList();
    return SafeArea(
      top: false,
      child: FractionallySizedBox(
        heightFactor: 0.85,
        child: Column(
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(top: 10),
              decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _q = v),
                decoration: InputDecoration(
                  hintText: 'Search country',
                  prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                itemBuilder: (context, i) {
                  final c = filtered[i];
                  return ListTile(
                    leading: Text(c.flag, style: const TextStyle(fontSize: 22)),
                    title: Text(c.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    trailing: Text(c.dial, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w600)),
                    onTap: () => Navigator.of(context).pop(c),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
