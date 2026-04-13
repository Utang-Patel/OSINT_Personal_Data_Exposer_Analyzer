import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/api_service.dart';

class ChangeEmailPage extends StatefulWidget {
  final String currentEmail;
  const ChangeEmailPage({super.key, required this.currentEmail});

  @override
  State<ChangeEmailPage> createState() => _ChangeEmailPageState();
}

class _ChangeEmailPageState extends State<ChangeEmailPage> {
  final _newEmailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _newEmailController.dispose();
    super.dispose();
  }

  Future<void> _requestOtp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final result = await ApiService().requestEmailChange(
        widget.currentEmail,
        _newEmailController.text.trim(),
      );
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _VerifyEmailChangePage(
            currentEmail: widget.currentEmail,
            newEmail: _newEmailController.text.trim(),
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
        title: const Text("Change Email",
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
                const Icon(Icons.email_outlined, size: 64, color: Colors.blueAccent),
                const SizedBox(height: 20),
                Text("Update your email address",
                    style: TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                const SizedBox(height: 8),
                Text("A verification code will be sent to your new email.",
                    style: TextStyle(fontSize: 14, color: colorScheme.onSurface.withOpacity(0.6))),
                const SizedBox(height: 32),

                // Current email (read-only)
                TextFormField(
                  initialValue: widget.currentEmail,
                  readOnly: true,
                  style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5)),
                  decoration: InputDecoration(
                    labelText: "Current Email",
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

                // New email input
                TextFormField(
                  controller: _newEmailController,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(color: colorScheme.onSurface),
                  decoration: InputDecoration(
                    labelText: "New Email",
                    labelStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
                    prefixIcon: const Icon(Icons.email_outlined, color: Colors.blueAccent),
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
                    if (v == null || v.isEmpty) return 'Please enter a new email';
                    if (!RegExp(r'^[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}$').hasMatch(v.trim())) {
                      return 'Please enter a valid email address';
                    }
                    if (v.trim().toLowerCase() == widget.currentEmail.toLowerCase()) {
                      return 'New email must be different from current email';
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
                        ? const SizedBox(
                            height: 20, width: 20,
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
// OTP Verification screen for email change
// ─────────────────────────────────────────────────────────────────────────────

class _VerifyEmailChangePage extends StatefulWidget {
  final String currentEmail;
  final String newEmail;
  final String? devOtp;

  const _VerifyEmailChangePage({
    required this.currentEmail,
    required this.newEmail,
    this.devOtp,
  });

  @override
  State<_VerifyEmailChangePage> createState() => _VerifyEmailChangePageState();
}

class _VerifyEmailChangePageState extends State<_VerifyEmailChangePage> {
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
      await ApiService().verifyEmailChange(widget.currentEmail, otp);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      // Pop back to profile
      Navigator.of(context).popUntil((route) => route.isFirst || route.settings.name == '/profile');
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
        title: const Text("Verify New Email",
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
              Text("Verify Your New Email",
                  style: TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
              const SizedBox(height: 10),
              Text("We've sent a 6-digit code to\n${widget.newEmail}",
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
                              style: TextStyle(
                                  color: Colors.orangeAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(widget.devOtp!,
                          style: const TextStyle(
                              color: Colors.orangeAccent,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 8)),
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
                    style: TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
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
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("Verify & Update Email",
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
