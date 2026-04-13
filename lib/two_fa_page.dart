import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/api_service.dart';

class TwoFAPage extends StatefulWidget {
  final String email;
  const TwoFAPage({super.key, required this.email});

  @override
  State<TwoFAPage> createState() => _TwoFAPageState();
}

class _TwoFAPageState extends State<TwoFAPage> {
  bool _isEnabled = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final enabled = await ApiService().get2FAStatus(widget.email);
    if (mounted) setState(() { _isEnabled = enabled; _isLoading = false; });
  }

  Future<void> _toggle() async {
    final action = _isEnabled ? 'disable' : 'enable';
    setState(() => _isLoading = true);
    try {
      final result = await ApiService().request2FAToggle(widget.email, action);
      if (!mounted) return;
      // Navigate to OTP verification
      final confirmed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => _TwoFAVerifyPage(
            email: widget.email,
            action: action,
            devOtp: result['otp']?.toString(),
          ),
        ),
      );
      if (confirmed == true) {
        setState(() => _isEnabled = action == 'enable');
      }
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
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Two-Factor Auth",
            style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Center(
                child: Icon(
                  _isEnabled ? Icons.shield : Icons.shield_outlined,
                  size: 80,
                  color: _isEnabled ? Colors.green : Colors.blueAccent,
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Text(
                  _isEnabled ? "2FA is Enabled" : "2FA is Disabled",
                  style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold,
                    color: _isEnabled ? Colors.green : colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  _isEnabled
                      ? "Your account is protected with two-factor authentication."
                      : "Add an extra layer of security to your account.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: colorScheme.onSurface.withOpacity(0.6)),
                ),
              ),
              const SizedBox(height: 40),

              // Status card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: (_isEnabled ? Colors.green : Colors.blueAccent).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: (_isEnabled ? Colors.green : Colors.blueAccent).withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.email_outlined,
                            color: _isEnabled ? Colors.green : Colors.blueAccent),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Email Authentication",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                              const SizedBox(height: 4),
                              Text(
                                "A 6-digit code will be sent to ${widget.email} every time you log in.",
                                style: TextStyle(
                                    fontSize: 12, color: colorScheme.onSurface.withOpacity(0.6)),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: (_isEnabled ? Colors.green : Colors.grey).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _isEnabled ? "ON" : "OFF",
                            style: TextStyle(
                              color: _isEnabled ? Colors.green : Colors.grey,
                              fontWeight: FontWeight.bold, fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _toggle,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isEnabled ? Colors.redAccent : Colors.blueAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 4,
                  ),
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(
                          _isEnabled ? "Disable Two-Factor Auth" : "Enable Two-Factor Auth",
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),

              if (_isEnabled) const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// OTP verification for enabling/disabling 2FA
// ─────────────────────────────────────────────────────────────────────────────

class _TwoFAVerifyPage extends StatefulWidget {
  final String email;
  final String action;
  final String? devOtp;
  const _TwoFAVerifyPage({required this.email, required this.action, this.devOtp});

  @override
  State<_TwoFAVerifyPage> createState() => _TwoFAVerifyPageState();
}

class _TwoFAVerifyPageState extends State<_TwoFAVerifyPage> {
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
      await ApiService().verify2FAToggle(widget.email, otp, widget.action);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Two-factor authentication ${widget.action}d successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
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
    final isEnable = widget.action == 'enable';
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          onPressed: () => Navigator.pop(context, false),
        ),
        title: Text("${isEnable ? 'Enable' : 'Disable'} 2FA",
            style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 16),
              Icon(isEnable ? Icons.shield_outlined : Icons.no_encryption_outlined,
                  size: 72, color: Colors.blueAccent),
              const SizedBox(height: 20),
              Text("${isEnable ? 'Enable' : 'Disable'} Two-Factor Auth",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold,
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
                      : Text("Confirm ${isEnable ? 'Enable' : 'Disable'}",
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
