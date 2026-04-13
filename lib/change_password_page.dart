import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'forgot_password_page.dart';

class ChangePasswordPage extends StatefulWidget {
  final String email;
  const ChangePasswordPage({super.key, required this.email});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await ApiService().changePassword(
        widget.email,
        _oldPasswordController.text,
        _newPasswordController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password changed successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
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

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool obscure,
    required VoidCallback onToggle,
    required String? Function(String?) validator,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      style: TextStyle(color: colorScheme.onSurface),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
        prefixIcon: Icon(icon, color: Colors.blueAccent),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_off : Icons.visibility,
              color: colorScheme.onSurface.withOpacity(0.5)),
          onPressed: onToggle,
        ),
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
    );
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
        title: const Text("Change Password",
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
                const Icon(Icons.lock_outline, size: 64, color: Colors.blueAccent),
                const SizedBox(height: 20),
                Text("Update your password",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface)),
                const SizedBox(height: 8),
                Text("Enter your current password and choose a new one.",
                    style: TextStyle(fontSize: 14, color: colorScheme.onSurface.withOpacity(0.6))),
                const SizedBox(height: 32),

                // Old password
                _buildPasswordField(
                  controller: _oldPasswordController,
                  label: "Current Password",
                  icon: Icons.lock_outline,
                  obscure: _obscureOld,
                  onToggle: () => setState(() => _obscureOld = !_obscureOld),
                  validator: (v) => (v == null || v.isEmpty) ? 'Enter your current password' : null,
                ),
                const SizedBox(height: 16),

                // New password
                _buildPasswordField(
                  controller: _newPasswordController,
                  label: "New Password",
                  icon: Icons.lock_reset_outlined,
                  obscure: _obscureNew,
                  onToggle: () => setState(() => _obscureNew = !_obscureNew),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter a new password';
                    if (v.length < 8) return 'Password must be at least 8 characters';
                    if (!RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).+$').hasMatch(v)) {
                      return 'Include uppercase, lowercase, and a number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Confirm new password
                _buildPasswordField(
                  controller: _confirmPasswordController,
                  label: "Re-enter New Password",
                  icon: Icons.lock_clock_outlined,
                  obscure: _obscureConfirm,
                  onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  validator: (v) {
                    if (v != _newPasswordController.text) return 'Passwords do not match';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Forgot password link
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ForgotPasswordPage()),
                    ),
                    child: const Text("Forgot Password?",
                        style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 24),

                // Change password button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _changePassword,
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
                        : const Text("Change Password",
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
