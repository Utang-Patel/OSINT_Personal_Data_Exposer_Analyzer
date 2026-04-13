import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'services/api_service.dart';

class EditProfilePage extends StatefulWidget {
  final String firstName;
  final String lastName;
  final String? profilePicturePath;

  const EditProfilePage({
    super.key,
    required this.firstName,
    required this.lastName,
    this.profilePicturePath,
  });

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  final ImagePicker _picker = ImagePicker();

  // Holds the XFile from picker — works on all platforms
  XFile? _pickedFile;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(text: widget.firstName);
    _lastNameController = TextEditingController(text: widget.lastName);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 90,
      );
      if (image != null) {
        setState(() => _pickedFile = image);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.blueAccent),
                title: const Text('Take Photo'),
                onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.camera); },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.blueAccent),
                title: const Text('Choose from Gallery'),
                onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.gallery); },
              ),
              if (_pickedFile != null || widget.profilePicturePath != null)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.redAccent),
                  title: const Text('Remove Photo'),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() => _pickedFile = null);
                    ApiService().setProfilePicture(null);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Build the avatar image — uses XFile for newly picked, File for existing
  ImageProvider? _buildAvatarImage() {
    if (kIsWeb) return null;
    if (_pickedFile != null) return FileImage(File(_pickedFile!.path));
    if (widget.profilePicturePath != null) {
      final f = File(widget.profilePicturePath!);
      if (f.existsSync()) return FileImage(f);
    }
    return null;
  }

  Future<void> _saveProfile() async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    if (firstName.isEmpty || lastName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields'),
            backgroundColor: Colors.orangeAccent));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final api = ApiService();
      await api.updateProfile(firstName, lastName);

      // Save picture if a new one was picked
      if (_pickedFile != null && !kIsWeb) {
        String? savedPath;
        try {
          final appDir = await getApplicationDocumentsDirectory();
          // Create a dedicated subfolder to speed up cleanup and avoid listing all Documents
          final photosDir = Directory('${appDir.path}/profile_photos');
          if (!photosDir.existsSync()) {
            await photosDir.create(recursive: true);
          }

          // Generate a unique filename using timestamp to bust cache
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final destPath = '${photosDir.path}/profile_picture_$timestamp.jpg';
          final dest = File(destPath);

          // Find and delete any EXISTING profile pictures in the subfolder ONLY
          try {
            final List<FileSystemEntity> entities = await photosDir.list().toList();
            for (var entity in entities) {
              if (entity is File && 
                  entity.path.contains('profile_picture_') && 
                  entity.path.endsWith('.jpg')) {
                debugPrint('[ProfilePic] Deleting old: ${entity.path}');
                await entity.delete();
              }
            }
          } catch (e) {
            debugPrint('[ProfilePic] Error cleaning old files: $e');
          }

          // Copy picked file to permanent location
          await File(_pickedFile!.path).copy(destPath);

          // Verify the copy succeeded
          if (dest.existsSync() && await dest.length() > 0) {
            savedPath = destPath;
            debugPrint('[ProfilePic] Copy success: $savedPath (${await dest.length()} bytes)');
          } else {
            // Copy failed — use original picked path as fallback
            savedPath = _pickedFile!.path;
            debugPrint('[ProfilePic] Copy failed, using original: $savedPath');
          }
        } catch (e) {
          // getApplicationDocumentsDirectory failed — use original path
          savedPath = _pickedFile!.path;
          debugPrint('[ProfilePic] Exception, using original: $savedPath — $e');
        }

        await api.setProfilePicture(savedPath);
        final verify = await api.getProfilePicture();
        debugPrint('[ProfilePic] Final Verification: $verify');
      }

      if (mounted) {
        debugPrint('[ProfilePic] Navigating back with result: true');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated!'),
              backgroundColor: Colors.green));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')),
              backgroundColor: Colors.redAccent));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final avatarImage = _buildAvatarImage();
    final initial = _firstNameController.text.isNotEmpty
        ? _firstNameController.text[0].toUpperCase()
        : 'U';

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Edit Profile'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: const TextStyle(
            color: Colors.blueAccent, fontSize: 18,
            fontWeight: FontWeight.bold, letterSpacing: 2),
        iconTheme: IconThemeData(color: colorScheme.onSurface),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),

            // Avatar
            GestureDetector(
              onTap: _showImageSourceDialog,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.blueAccent,
                    backgroundImage: avatarImage,
                    child: avatarImage == null
                        ? Text(initial,
                            style: const TextStyle(fontSize: 48,
                                color: Colors.white, fontWeight: FontWeight.bold))
                        : null,
                  ),
                  Positioned(
                    bottom: 0, right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                          color: Colors.blueAccent, shape: BoxShape.circle),
                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text('Tap to change photo',
                style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6), fontSize: 14)),
            const SizedBox(height: 40),

            // First Name
            TextField(
              controller: _firstNameController,
              decoration: _inputDecoration(colorScheme, 'First Name', Icons.person_outline),
            ),
            const SizedBox(height: 16),

            // Last Name
            TextField(
              controller: _lastNameController,
              decoration: _inputDecoration(colorScheme, 'Last Name', Icons.person_outline),
            ),
            const SizedBox(height: 40),

            // Save
            ElevatedButton(
              onPressed: _isLoading ? null : _saveProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent, foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 4,
              ),
              child: _isLoading
                  ? const SizedBox(height: 20, width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Save Changes',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),

            // Cancel
            OutlinedButton(
              onPressed: _isLoading ? null : () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: colorScheme.onSurface,
                minimumSize: const Size(double.infinity, 56),
                side: BorderSide(color: colorScheme.onSurface.withOpacity(0.3)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Cancel', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(ColorScheme cs, String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.blueAccent),
      filled: true,
      fillColor: cs.surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.onSurface.withOpacity(0.1))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.onSurface.withOpacity(0.1))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.blueAccent, width: 2)),
    );
  }
}
