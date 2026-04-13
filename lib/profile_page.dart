import 'dart:io' show File;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme_provider.dart';
import 'login_page.dart';
import 'services/api_service.dart';
import 'edit_profile_page.dart';
import 'change_email_page.dart';
import 'change_phone_page.dart';
import 'change_password_page.dart';
import 'two_fa_page.dart';
import 'language_provider.dart';

class ProfilePage extends StatefulWidget {
  final VoidCallback? onBack;
  const ProfilePage({super.key, this.onBack});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String _firstName = 'User';
  String _lastName = 'Name';
  String _email = 'user@example.com';
  String _phone = '';
  String? _profilePicturePath;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final apiService = ApiService();
    final firstName = await apiService.getFirstName();
    final lastName = await apiService.getLastName();
    final email = await apiService.getEmail();
    final phone = await apiService.getPhone();
    final profilePicture = await apiService.getProfilePicture();

    // Clear image cache so the new file is loaded fresh
    if (!kIsWeb) {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    }

    if (mounted) {
      setState(() {
        _firstName = firstName ?? 'User';
        _lastName = lastName ?? 'Name';
        _email = email ?? 'user@example.com';
        _phone = phone ?? '';
        _profilePicturePath = profilePicture;
      });
    }
  }

  String _currentLanguageName(LanguageProvider lp) => lp.currentLanguageName;

  void _showLanguagePicker(LanguageProvider lp) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) {
        final colorScheme = Theme.of(context).colorScheme;
        final languages = ['English', 'Hindi', 'Spanish', 'French', 'German'];
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: colorScheme.onSurface.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Text(lp.translate('language'),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface)),
              const SizedBox(height: 8),
              ...languages.map((lang) => ListTile(
                leading: const Icon(Icons.language, color: Colors.blueAccent),
                title: Text(lang, style: TextStyle(color: colorScheme.onSurface)),
                trailing: lp.currentLanguageName == lang
                    ? const Icon(Icons.check, color: Colors.blueAccent)
                    : null,
                onTap: () {
                  lp.setLanguage(lang);
                  Navigator.pop(context);
                },
              )),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  ImageProvider? _getProfileImage() {
    if (_profilePicturePath == null || kIsWeb) return null;
    try {
      final f = File(_profilePicturePath!);
      final exists = f.existsSync();
      debugPrint('[ProfilePic] Display path: $_profilePicturePath, exists: $exists');
      if (exists) return FileImage(f);
    } catch (e) {
      debugPrint('[ProfilePic] Error: $e');
    }
    return null;
  }

  Widget _buildProfileAvatar() {
    final initial = _firstName.isNotEmpty ? _firstName[0].toUpperCase() : 'U';

    // Check if we have a valid image file
    bool hasImage = false;
    if (!kIsWeb && _profilePicturePath != null) {
      try {
        hasImage = File(_profilePicturePath!).existsSync();
      } catch (_) {}
    }

    return SizedBox(
      width: 120,
      height: 120,
      child: ClipOval(
        child: hasImage
            ? Image.file(
                File(_profilePicturePath!),
                // Use the path itself as the key. Since the filename now includes a 
                // timestamp, this key will change every time a new photo is saved.
                key: ValueKey(_profilePicturePath), 
                width: 120,
                height: 120,
                fit: BoxFit.cover,
                // These help ensure Flutter reloads from disk
                cacheWidth: null,
                cacheHeight: null,
                errorBuilder: (context, error, stackTrace) {
                  debugPrint('[ProfilePic] Error loading image: $error');
                  return _avatarFallback(initial);
                },
              )
            : _avatarFallback(initial),
      ),
    );
  }

  Widget _avatarFallback(String initial) {
    return Container(
      width: 120,
      height: 120,
      color: Colors.blueAccent,
      child: Center(
        child: Text(initial,
            style: const TextStyle(fontSize: 48, color: Colors.white,
                fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    final lp = Provider.of<LanguageProvider>(context, listen: false);
    final TextEditingController passwordController = TextEditingController();
    bool isDeleting = false;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              backgroundColor: Theme.of(context).colorScheme.surface,
              title: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.redAccent),
                  const SizedBox(width: 8),
                  Text(
                    lp.translate('delete_account'),
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lp.translate('delete_warning'),
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8)),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: lp.translate('enter_password'),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.lock_outline),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isDeleting ? null : () => Navigator.pop(dialogContext),
                  child: Text(lp.translate('cancel'), style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
                ),
                ElevatedButton(
                  onPressed: isDeleting
                      ? null
                      : () async {
                          if (passwordController.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(lp.translate('enter_password'))),
                            );
                            return;
                          }

                          setDialogState(() {
                            isDeleting = true;
                          });

                          try {
                            await ApiService().deleteAccount(passwordController.text);
                            if (context.mounted) {
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(builder: (context) => const LoginPage()),
                                (route) => false,
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(lp.translate('account_deleted'))),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              String errorMessage = e.toString().replaceAll('Exception: ', '');
                              if (errorMessage.contains('SocketException')) {
                                errorMessage = 'Connection refused. Please check if the backend is running and reachable.';
                              }
                              
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(errorMessage),
                                  backgroundColor: Colors.redAccent,
                                  duration: const Duration(seconds: 4),
                                ),
                              );
                            }
                          } finally {
                            if (dialogContext.mounted) {
                              setDialogState(() {
                                isDeleting = false;
                              });
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: isDeleting
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(lp.translate('delete'), style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showLogoutDialog(BuildContext context) {
    final lp = Provider.of<LanguageProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Text(
            lp.translate('logout'),
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold),
          ),
          content: Text(
            lp.translate('sure_logout'),
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(lp.translate('no'), style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(lp.translate('yes'), style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isDark = themeProvider.themeMode == ThemeMode.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Standardized Header
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20.0),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      left: 8,
                      child: IconButton(
                        icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
                        onPressed: () {
                          if (widget.onBack != null) {
                            widget.onBack!();
                          } else if (Navigator.canPop(context)) {
                            Navigator.pop(context);
                          }
                        },
                      ),
                    ),
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
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    // User Profile Header
                    _buildProfileAvatar(),
                    const SizedBox(height: 16),
                    Text(
                      "$_firstName $_lastName",
                      style: TextStyle(color: colorScheme.onSurface, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _email,
                      style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 16),
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton(
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EditProfilePage(
                              firstName: _firstName,
                              lastName: _lastName,
                              profilePicturePath: _profilePicturePath,
                            ),
                          ),
                        );
                        if (result == true) {
                          await _loadUserData(); // Refresh data
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blueAccent,
                        side: const BorderSide(color: Colors.blueAccent),
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                      child: Text(languageProvider.translate('edit_profile'), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 40),

                    // Settings Groups
                    _buildSettingsGroup(languageProvider.translate('personal_info'), [
                      _buildSettingsTile(context, Icons.email_outlined, languageProvider.translate('change_email'), lp: languageProvider),
                      _buildSettingsTile(context, Icons.phone_android_outlined, languageProvider.translate('phone_number'), lp: languageProvider),
                    ]),
                    const SizedBox(height: 24),
                    _buildSettingsGroup(languageProvider.translate('security'), [
                      _buildSettingsTile(context, Icons.lock_outline, languageProvider.translate('change_password'), lp: languageProvider),
                      _buildSettingsTile(context, Icons.security, languageProvider.translate('two_fa'), lp: languageProvider),
                    ]),
                    const SizedBox(height: 24),
                    _buildSettingsGroup(languageProvider.translate('preferences'), [
                      SwitchListTile(
                        value: isDark,
                        onChanged: (value) => themeProvider.toggleTheme(value),
                        secondary: const Icon(Icons.dark_mode_outlined, color: Colors.blueAccent),
                        title: Text(languageProvider.translate('dark_mode'), style: TextStyle(color: colorScheme.onSurface, fontSize: 16)),
                        activeThumbColor: Colors.blueAccent,
                      ),
                      _buildSettingsTile(context, Icons.language, languageProvider.translate('language'),
                          trailingText: _currentLanguageName(languageProvider), lp: languageProvider),
                    ]),
                    const SizedBox(height: 40),

                    // Action Buttons
                    ElevatedButton(
                      onPressed: () => _showLogoutDialog(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.surface,
                        foregroundColor: Colors.redAccent,
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: Text(languageProvider.translate('logout'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => _showDeleteAccountDialog(context),
                      child: Text(languageProvider.translate('delete_account'), style: const TextStyle(color: Colors.redAccent, decoration: TextDecoration.underline)),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsGroup(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSettingsTile(BuildContext context, IconData icon, String title, {String? trailingText, required LanguageProvider lp}) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: Colors.blueAccent, size: 22),
      title: Text(title, style: TextStyle(color: colorScheme.onSurface, fontSize: 16)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingText != null)
            Text(
              trailingText,
              style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 14),
            ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, color: colorScheme.onSurface.withOpacity(0.2)),
        ],
      ),
      onTap: () {
        if (title == lp.translate('change_email')) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChangeEmailPage(currentEmail: _email),
            ),
          ).then((_) => _loadUserData());
        } else if (title == lp.translate('phone_number')) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChangePhonePage(currentPhone: _phone, email: _email),
            ),
          ).then((_) => _loadUserData());
        } else if (title == lp.translate('change_password')) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChangePasswordPage(email: _email),
            ),
          );
        } else if (title == lp.translate('two_fa')) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TwoFAPage(email: _email),
            ),
          );
        } else if (title == lp.translate('language')) {
          _showLanguagePicker(lp);
        }
      },
    );
  }
}
