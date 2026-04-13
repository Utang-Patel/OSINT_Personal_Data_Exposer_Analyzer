import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'reset_password_page.dart';
import 'services/api_service.dart';
import 'login_page.dart';

class OTPValidationPage extends StatefulWidget {
  final String email;
  final bool isForgotPassword;
  final String? devOtp; // shown on screen when email delivery fails

  const OTPValidationPage({
    super.key,
    required this.email,
    this.isForgotPassword = false,
    this.devOtp,
  });

  @override
  State<OTPValidationPage> createState() => _OTPValidationPageState();
}

class _OTPValidationPageState extends State<OTPValidationPage> {

  // ✅ CHANGED 4 → 6
  final List<TextEditingController> _controllers =
      List.generate(6, (index) => TextEditingController());

  final List<FocusNode> _focusNodes =
      List.generate(6, (index) => FocusNode());

  bool _isLoading = false;
  bool _isResending = false;

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _handleVerify() async {
    String otp = _controllers.map((e) => e.text).join();

    // ✅ CHANGED 4 → 6
    if (otp.length == 6) {
      if (widget.isForgotPassword) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ResetPasswordPage(email: widget.email)),
        );
      } else {
        setState(() => _isLoading = true);
        try {
          await ApiService().verifyOTP(widget.email, otp);
          if (!mounted) return;

          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const LoginPage()),
            (route) => false,
          );
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString()),
              backgroundColor: Colors.redAccent,
            ),
          );
        } finally {
          if (mounted) setState(() => _isLoading = false);
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a 6-digit OTP')),
      );
    }
  }

  Future<void> _handleResend() async {
    setState(() => _isResending = true);
    try {
      await ApiService().resendOTP(widget.email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A new code has been sent to your email'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isResending = false);
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
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "OSINT Data Analyzer",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    color: Colors.blueAccent,
                  ),
                ),
                const SizedBox(height: 16),
                const Icon(
                  Icons.mark_email_read_outlined,
                  size: 80,
                  color: Colors.blueAccent,
                ),
                const SizedBox(height: 24),
                Text(
                  widget.isForgotPassword
                      ? "Enter Reset Code"
                      : "Verify Your Email",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),

                // ✅ Updated text
                Text(
                  "We've sent a 6-digit code to\n${widget.email}",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 40),

                // Dev OTP banner — shown when email delivery fails
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
                            Text(
                              "Email not sent — Dev Mode OTP",
                              style: TextStyle(
                                color: Colors.orangeAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.devOtp!,
                          style: const TextStyle(
                            color: Colors.orangeAccent,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 8,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "Fix EMAIL_HOST_PASSWORD in .env for production",
                          style: TextStyle(color: Colors.orangeAccent, fontSize: 11),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // OTP input boxes
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(
                    6,
                    (index) => SizedBox(
                      width: 50,
                      child: TextFormField(
                        controller: _controllers[index],
                        focusNode: _focusNodes[index],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(1),
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (value) {
                          // ✅ Updated focus logic for 6
                          if (value.isNotEmpty && index < 5) {
                            _focusNodes[index + 1].requestFocus();
                          } else if (value.isEmpty && index > 0) {
                            _focusNodes[index - 1].requestFocus();
                          }
                        },
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: colorScheme.surface,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: colorScheme.onSurface.withOpacity(0.1),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Colors.blueAccent,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _handleVerify,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      padding:
                          const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            "Verify OTP",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Didn't receive code? ",
                      style: TextStyle(
                        color:
                            colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                    TextButton(
                      onPressed:
                          _isResending ? null : _handleResend,
                      child: _isResending
                          ? const SizedBox(
                              height: 12,
                              width: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              "Resend",
                              style: TextStyle(
                                color: Colors.blueAccent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}