import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/api_service.dart';
import 'home_page.dart';

class TwoFALoginPage extends StatefulWidget {
  final String email;
  final String? devOtp;
  const TwoFALoginPage({super.key, required this.email, this.devOtp});

  @override
  State<TwoFALoginPage> createState() => _TwoFALoginPageState();
}

class _TwoFALoginPageState extends State<TwoFALoginPage> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isLoading = false;

  @override
  void dispose() {
    for (var c in _controllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _verify() async {
    final otp = _controllers.map((c) => c.text).join();
    if (otp.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the 6-digit code')));
      return;
    }
    setState(() => _isLoading = true);
    try {
      await ApiService().verify2FALogin(widget.email, otp);
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 40),
              const Text("OSINT Data Analyzer",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                      letterSpacing: 2, color: Colors.blueAccent)),
              const SizedBox(height: 32),
              const Icon(Icons.shield_outlined, size: 72, color: Colors.blueAccent),
              const SizedBox(height: 20),
              Text("Two-Factor Authentication",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface)),
              const SizedBox(height: 10),
              Text("Enter the 6-digit code sent to\n${widget.email}",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: colorScheme.onSurface.withOpacity(0.6))),
              const SizedBox(height: 28),

              if (widget.devOtp != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.orangeAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orangeAccent.withOpacity(0.5)),
                  ),
                  child: Column(
                    children: [
                      const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 18),
                        SizedBox(width: 6),
                        Text("Dev Mode OTP", style: TextStyle(
                            color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                      ]),
                      const SizedBox(height: 8),
                      Text(widget.devOtp!, style: const TextStyle(
                          color: Colors.orangeAccent, fontSize: 32,
                          fontWeight: FontWeight.bold, letterSpacing: 8)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(6, (i) => SizedBox(
                  width: 48,
                  child: TextFormField(
                    controller: _controllers[i],
                    focusNode: _focusNodes[i],
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface),
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(1),
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    onChanged: (v) {
                      if (v.isNotEmpty && i < 5) _focusNodes[i + 1].requestFocus();
                      if (v.isEmpty && i > 0) _focusNodes[i - 1].requestFocus();
                    },
                    decoration: InputDecoration(
                      filled: true, fillColor: colorScheme.surface,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: colorScheme.onSurface.withOpacity(0.15)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
                      ),
                    ),
                  ),
                )),
              ),
              const SizedBox(height: 36),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verify,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 4,
                  ),
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("Verify & Login",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
