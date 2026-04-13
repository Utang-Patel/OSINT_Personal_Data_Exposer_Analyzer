import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'language_provider.dart';
import 'login_page.dart';
import 'otp_validation_page.dart';
import 'services/api_service.dart';
import 'home_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String _selectedCountryCode = '+91'; // Default to India

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();


  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }


  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your email';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters long';
    }
    if (!RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).+$').hasMatch(value)) {
      return 'Include uppercase, lowercase, and numbers';
    }
    return null;
  }

  Future<void> _handleRegister() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final fullPhone = '$_selectedCountryCode${_phoneController.text.trim()}';
        final result = await ApiService().register(
          _emailController.text.trim(),
          _passwordController.text.trim(),
          _firstNameController.text.trim(),
          _lastNameController.text.trim(),
          fullPhone,
        );

        if (!mounted) return;

        final devOtp = result['otp']?.toString();
        final warning = result['warning']?.toString();

        if (warning != null && devOtp != null) {
          // Email failed — show OTP in snackbar for dev use
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Email not sent. Dev OTP: $devOtp'),
              backgroundColor: Colors.orangeAccent,
              duration: const Duration(seconds: 15),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('OTP sent to your email!')),
          );
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => OTPValidationPage(
              email: _emailController.text.trim(),
              devOtp: devOtp,
            ),
          ),
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    try {
      await ApiService().googleLogin();
      if (!mounted) return;
      
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final lp = Provider.of<LanguageProvider>(context);
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    lp.translate('app_title'),
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
                    Icons.person_add_outlined,
                    size: 70,
                    color: Colors.blueAccent,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    lp.translate('create_account'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    lp.translate('fill_details'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _firstNameController,
                          label: lp.translate('first_name'),
                          icon: Icons.person_outline,
                          validator: (v) => v!.isEmpty ? lp.translate('required') : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: _lastNameController,
                          label: lp.translate('last_name'),
                          icon: Icons.person_outline,
                          validator: (v) => v!.isEmpty ? lp.translate('required') : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _emailController,
                    label: lp.translate('email'),
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.isEmpty) return lp.translate('enter_email');
                      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                      if (!emailRegex.hasMatch(v)) return lp.translate('invalid_email');
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colorScheme.onSurface.withOpacity(0.1)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedCountryCode,
                            items: const [
                              DropdownMenuItem(value: '+1', child: Text('+1 (US/CA)')),
                              DropdownMenuItem(value: '+44', child: Text('+44 (UK)')),
                              DropdownMenuItem(value: '+61', child: Text('+61 (AU)')),
                              DropdownMenuItem(value: '+91', child: Text('+91 (IN)')),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _selectedCountryCode = value);
                              }
                            },
                            style: TextStyle(color: colorScheme.onSurface, fontSize: 16),
                            dropdownColor: colorScheme.surface,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: _phoneController,
                          label: lp.translate('phone_number'),
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          validator: (v) {
                            if (v == null || v.isEmpty) return lp.translate('required');
                            final cleaned = v.replaceAll(RegExp(r'[\s\-]'), '');
                            if (cleaned.length < 7 || cleaned.length > 15) {
                              return lp.translate('invalid_phone');
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _usernameController,
                    label: lp.translate('username'),
                    icon: Icons.person_outline,
                    validator: (v) {
                      if (v == null || v.isEmpty) return lp.translate('enter_username');
                      if (v.length < 3) return lp.translate('username_too_short'); // Assuming this exists or falls back
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _passwordController,
                    label: lp.translate('password'),
                    icon: Icons.lock_outline,
                    isPassword: true,
                    obscureText: _obscurePassword,
                    onToggleVisibility: () => setState(() => _obscurePassword = !_obscurePassword),
                    validator: (v) {
                      if (v == null || v.isEmpty) return lp.translate('enter_password');
                      if (v.length < 8) return lp.translate('password_too_short'); 
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _confirmPasswordController,
                    label: lp.translate('confirm_password'),
                    icon: Icons.lock_clock_outlined,
                    isPassword: true,
                    obscureText: _obscureConfirmPassword,
                    onToggleVisibility: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                    validator: (v) {
                      if (v != _passwordController.text) {
                        return lp.translate('passwords_dont_match');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleRegister,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
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
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            lp.translate('register'),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const LoginPage()),
                      );
                    },
                    child: Text(
                      lp.translate('already_have_account'),
                      style: TextStyle(color: colorScheme.onSurface.withOpacity(0.7)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onToggleVisibility,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(color: colorScheme.onSurface),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
        prefixIcon: Icon(icon, color: Colors.blueAccent),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  obscureText ? Icons.visibility_off : Icons.visibility,
                  color: colorScheme.onSurface.withOpacity(0.6),
                ),
                onPressed: onToggleVisibility,
              )
            : null,
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
}
