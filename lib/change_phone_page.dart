import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/api_service.dart';

class ChangePhonePage extends StatefulWidget {
  final String currentPhone;
  final String email;
  const ChangePhonePage({super.key, required this.currentPhone, required this.email});

  @override
  State<ChangePhonePage> createState() => _ChangePhonePageState();
}

class _ChangePhonePageState extends State<ChangePhonePage> {
  final _newPhoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _newPhoneController.dispose();
    super.dispose();
  }

  Future<void> _requestOtp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final result = await ApiService().requestPhoneChange(
        widget.email,
        _newPhoneController.text.trim(),
      );
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _VerifyPhoneChangePage(
            email: widget.email,
            newPhone: _newPhoneController.text.trim(),
            devOtp: result['otp']?.toString(),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent),
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Phone Number",
            style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                const Icon(Icons.phone_android_outlined, size: 64, color: Colors.blueAccent),
                const SizedBox(height: 20),
                Text("Update your phone number",
                    style: TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                const SizedBox(height: 8),
                Text("A verification code will be sent to your email address.",
                    style: TextStyle(fontSize: 14, color: colorScheme.onSurface.withOpacity(0.6))),
                const SizedBox(height: 32),

                // Current phone (read-only)
                TextFormField(
                  initialValue: widget.currentPhone.isEmpty ? 'Not set' : widget.currentPhone,
                  readOnly: true,
                  style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5)),
                  decoration: InputDecoration(
                    labelText: "Current Phone Number",
                    labelStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.5)),
                    prefixIcon: const Icon(Icons.lock_outline, color: Colors.blueAccent),
                    filled: true,
                    fillColor: colorScheme.surface,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colorScheme.onSurface.withOpacity(0.1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colorScheme.onSurface.withOpacity(0.1)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // New phone input
                TextFormField(
                  controller: _newPhoneController,
                  keyboardType: TextInputType.phone,
                  style: TextStyle(color: colorScheme.onSurface),
                  decoration: InputDecoration(
                    labelText: "New Phone Number",
                    hintText: "+91XXXXXXXXXX",
                    hintStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.3)),
                    labelStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
                    prefixIcon: const Icon(Icons.phone_outlined, color: Colors.blueAccent),
                    filled: true,
                    fillColor: colorScheme.surface,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colorScheme.onSurface.withOpacity(0.1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.redAccent),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.redAccent, width: 2),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Please enter a new phone number';
                    final cleaned = v.trim().replaceAll(RegExp(r'[\s\-()]'), '');
                    if (cleaned.length < 7 || cleaned.length > 16) return 'Enter a valid phone number';
                    if (cleaned == widget.currentPhone.replaceAll(RegExp(r'[\s\-()]'), '')) {
                      return 'New number must be different from current';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _requestOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 4,
                    ),
                    child: _isLoading
                        ? const SizedBox(height: 20, width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text("Send Verification Code",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// OTP Verification screen for phone change
// ─────────────────────────────────────────────────────────────────────────────

class _VerifyPhoneChangePage extends StatefulWidget {
  final String email;
  final String newPhone;
  final String? devOtp;

  const _VerifyPhoneChangePage({
    required this.email,
    required this.newPhone,
    this.devOtp,
  });

  @override
  State<_VerifyPhoneChangePage> createState() => _VerifyPhoneChangePageState();
}

class _VerifyPhoneChangePageState extends State<_VerifyPhoneChangePage> {
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
      await ApiService().verifyPhoneChange(widget.email, otp);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Phone number updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop();
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent),
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Verify Phone Change",
            style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 16),
              const Icon(Icons.mark_email_read_outlined, size: 72, color: Colors.blueAccent),
              const SizedBox(height: 20),
              Text("Verify Phone Change",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface)),
              const SizedBox(height: 10),
              Text("We've sent a 6-digit code to\n${widget.email}",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: colorScheme.onSurface.withOpacity(0.6))),
              const SizedBox(height: 28),

              // Dev OTP banner
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
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 18),
                          SizedBox(width: 6),
                          Text("Email not sent — Dev Mode OTP",
                              style: TextStyle(color: Colors.orangeAccent,
                                  fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(widget.devOtp!,
                          style: const TextStyle(color: Colors.orangeAccent,
                              fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 8)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // OTP boxes
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
                      filled: true,
                      fillColor: colorScheme.surface,
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
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 4,
                  ),
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("Verify & Update Phone",
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
