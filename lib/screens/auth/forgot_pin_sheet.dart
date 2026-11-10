import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sanjay_roadlines_fleet/core/constants/app_colors.dart';
import 'package:sanjay_roadlines_fleet/repositories/auth_repository.dart';

/// Admin "Forgot Login PIN": User ID + mobile → code by email → new Login PIN.
class ForgotPinSheet extends StatefulWidget {
  const ForgotPinSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (_) => const ForgotPinSheet(),
      );

  @override
  State<ForgotPinSheet> createState() => _ForgotPinSheetState();
}

class _ForgotPinSheetState extends State<ForgotPinSheet> {
  final _repo = AuthRepository();
  final _userId = TextEditingController();
  final _mobile = TextEditingController();
  final _code = TextEditingController();
  final _pin = TextEditingController();
  final _pin2 = TextEditingController();
  String? _sentTo;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_userId, _mobile, _code, _pin, _pin2]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _run(Future<void> Function() job) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await job();
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _send() => _run(() async {
        if (_userId.text.trim().isEmpty || _mobile.text.trim().length != 10) {
          throw Exception('Enter your User ID and 10-digit mobile number');
        }
        _sentTo = await _repo.sendPinResetCode(_userId.text, _mobile.text);
      });

  Future<void> _save() => _run(() async {
        if (_code.text.trim().length != 6) throw Exception('Enter the 6-digit code from the email');
        if (_pin.text.length != 4) throw Exception('Login PIN must be exactly 4 digits');
        if (_pin.text != _pin2.text) throw Exception('The two Login PINs do not match');
        await _repo.resetPinWithCode(_userId.text, _mobile.text, _code.text, _pin.text);
        if (!mounted) return;
        final messenger = ScaffoldMessenger.of(context);
        Navigator.of(context).pop();
        messenger.showSnackBar(const SnackBar(
          content: Text('Login PIN updated. Log in with your new Login PIN.'),
          backgroundColor: AppColors.successGreen,
        ));
      });

  InputDecoration _dec(String label) => InputDecoration(labelText: label, counterText: '');

  @override
  Widget build(BuildContext context) {
    final codeSent = _sentTo != null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Forgot Login PIN', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('For admins. Drivers: ask your admin to reset your Login PIN.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            TextField(
              controller: _userId,
              enabled: !codeSent,
              textCapitalization: TextCapitalization.characters,
              decoration: _dec('User ID'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _mobile,
              enabled: !codeSent,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: _dec('Registered mobile number'),
            ),
            if (codeSent) ...[
              const SizedBox(height: 12),
              Text('Code sent to $_sentTo. Check inbox and spam.',
                  style: const TextStyle(color: AppColors.successGreen, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              TextField(
                controller: _code,
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: _dec('6-digit code from email'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _pin,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: _dec('New Login PIN (4 digits)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _pin2,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: _dec('Confirm new Login PIN'),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.errorRed)),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _busy ? null : (codeSent ? _save : _send),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandYellow,
                foregroundColor: AppColors.ink,
                minimumSize: const Size.fromHeight(48),
              ),
              child: _busy
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(codeSent ? 'UPDATE LOGIN PIN' : 'SEND CODE'),
            ),
            if (codeSent)
              TextButton(onPressed: _busy ? null : _send, child: const Text('Resend code')),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
