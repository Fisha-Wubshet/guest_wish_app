import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/locale/locale_provider.dart';

/// Bottom sheet that shows a newly-created account's login credentials with
/// language toggle (en/am), copy button and native share button. Used from
/// both the super admin's "create shop" flow and the shop admin's "add staff"
/// flow.
class CredentialsShareSheet extends StatefulWidget {
  final String firstName;
  final String lastName;
  final String phone;
  final String password;
  final String? recoveryCode;
  final String? userEmail;
  final bool emailSent;
  final String loginUrl;

  const CredentialsShareSheet({
    super.key,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.password,
    this.recoveryCode,
    this.userEmail,
    this.emailSent = false,
    this.loginUrl = 'https://rent.gizebit.com/login',
  });

  static Future<void> show(
    BuildContext context, {
    required String firstName,
    required String lastName,
    required String phone,
    required String password,
    String? recoveryCode,
    String? userEmail,
    bool emailSent = false,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CredentialsShareSheet(
        firstName: firstName,
        lastName: lastName,
        phone: phone,
        password: password,
        recoveryCode: recoveryCode,
        userEmail: userEmail,
        emailSent: emailSent,
      ),
    );
  }

  @override
  State<CredentialsShareSheet> createState() => _CredentialsShareSheetState();
}

class _CredentialsShareSheetState extends State<CredentialsShareSheet> {
  late String _lang = appLocale == 'am' ? 'am' : 'en';
  bool _copied = false;

  String get _fullName => '${widget.firstName} ${widget.lastName}'.trim();

  String get _message {
    if (_lang == 'am') {
      final buf = StringBuffer();
      buf.writeln('👋 ሰላም $_fullName፣');
      buf.writeln();
      buf.writeln('የGizeBit መለያዎ ተፈጥሯል። ከታች ያሉት የመግቢያ መረጃዎችዎ ናቸው።');
      buf.writeln();
      buf.writeln('📱 ስልክ: ${widget.phone}');
      buf.writeln('🔑 ፓስዎርድ: ${widget.password}');
      if ((widget.recoveryCode ?? '').isNotEmpty) {
        buf.writeln('🛡 የመልሶ ማግኛ ኮድ: ${widget.recoveryCode}');
      }
      buf.writeln();
      buf.writeln('🔗 ${widget.loginUrl}');
      buf.writeln();
      buf.write('⚠ ይህ ፓስዎርድ አንድ ጊዜ ብቻ ይሠራል። ከገቡ በኋላ አዲስ ፓስዎርድ እንዲያዘጋጁ ይጠየቃሉ።');
      if ((widget.recoveryCode ?? '').isNotEmpty) {
        buf.writeln();
        buf.writeln();
        buf.write('🛡 የመልሶ ማግኛ ኮድዎ ፓስዎርድ ከረሱ ዳግም ለማስተካከል የመጠባበቂያ ቁልፍ ነው። በደህና ቦታ ያስቀምጡ።');
        if ((widget.userEmail ?? '').isNotEmpty) {
          buf.write(' ኮዱን ካጡ በኢሜይል ደግሞ ማስተካከል ይችላሉ።');
        }
      }
      return buf.toString();
    }
    final buf = StringBuffer();
    buf.writeln('👋 Hi $_fullName,');
    buf.writeln();
    buf.writeln('Your GizeBit account has been created. Here are your login details:');
    buf.writeln();
    buf.writeln('📱 Phone: ${widget.phone}');
    buf.writeln('🔑 Password: ${widget.password}');
    if ((widget.recoveryCode ?? '').isNotEmpty) {
      buf.writeln('🛡 Recovery code: ${widget.recoveryCode}');
    }
    buf.writeln();
    buf.writeln('🔗 ${widget.loginUrl}');
    buf.writeln();
    buf.write("⚠ This password will only work once. You'll be asked to set a new one right after signing in.");
    if ((widget.recoveryCode ?? '').isNotEmpty) {
      buf.writeln();
      buf.writeln();
      buf.write('🛡 Your recovery code is a backup key to reset your password if you forget it. Save it somewhere safe.');
      if ((widget.userEmail ?? '').isNotEmpty) {
        buf.write(' If you lose the code, you can also reset via email.');
      }
    }
    return buf.toString();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _message));
    if (!mounted) return;
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  Future<void> _share() async {
    await Share.share(_message, subject: 'GizeBit login details');
  }

  @override
  Widget build(BuildContext context) {
    final am = _lang == 'am';
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final hasEmail = (widget.userEmail ?? '').isNotEmpty;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(0, 8, 0, bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36, height: 4, margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Container(
              color: const Color(0xFFECFDF5),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(color: const Color(0xFFD1FAE5), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.check_circle_outline, color: Color(0xFF059669), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(am ? 'መለያ ተፈጥሯል' : 'Account created',
                            style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: Color(0xFF064E3B))),
                        const SizedBox(height: 3),
                        Text(
                          am ? 'የ$_fullName የመግቢያ መረጃ' : 'Login details for $_fullName',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF047857), height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Text(
                    am ? 'የመልእክት ቋንቋ' : 'MESSAGE LANGUAGE',
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.6),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _langBtn('en', '🇬🇧 EN'),
                        _langBtn('am', '🇪🇹 አማ'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
              child: Container(
                constraints: const BoxConstraints(maxHeight: 320),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    _message,
                    style: const TextStyle(fontSize: 13, height: 1.55, color: Color(0xFF0F172A)),
                  ),
                ),
              ),
            ),
            if (widget.emailSent)
              _note(icon: Icons.mark_email_read_outlined, tone: 'success',
                    text: am
                        ? 'የእንኳን ደህና መጡ ኢሜይል ወደ ${widget.userEmail} ተልኳል።'
                        : 'A welcome email was sent to ${widget.userEmail}.'),
            if (!widget.emailSent && !hasEmail)
              _note(icon: Icons.email_outlined, tone: 'warning',
                    text: am
                        ? 'ኢሜይል አልተመዘገበም — በWhatsApp፣ SMS ወይም ኮፒ አድርገው ያጋሩ።'
                        : 'No email on file — share via WhatsApp, SMS or copy the details.'),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(am ? 'ዝጋ' : 'Close', style: const TextStyle(color: Color(0xFF64748B))),
                  ),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: _copy,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF7C3AED),
                      side: const BorderSide(color: Color(0xFFD8B4FE)),
                      backgroundColor: const Color(0xFFF3F0FF),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: Icon(_copied ? Icons.check : Icons.content_copy, size: 16),
                    label: Text(_copied ? (am ? 'ተቀድቷል' : 'Copied') : (am ? 'ኮፒ' : 'Copy')),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _share,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.share_outlined, size: 16),
                    label: Text(am ? 'አጋራ' : 'Share'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _langBtn(String value, String label) {
    final active = _lang == value;
    return GestureDetector(
      onTap: () => setState(() => _lang = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: active ? [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 3, offset: const Offset(0, 1))] : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: active ? const Color(0xFF7C3AED) : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _note({required IconData icon, required String tone, required String text}) {
    final success = tone == 'success';
    final bg = success ? const Color(0xFFECFDF5) : const Color(0xFFFFF7ED);
    final fg = success ? const Color(0xFF059669) : const Color(0xFFB45309);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
        child: Row(
          children: [
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 6),
            Expanded(child: Text(text, style: TextStyle(fontSize: 12, color: fg))),
          ],
        ),
      ),
    );
  }
}
