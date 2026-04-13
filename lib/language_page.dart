import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'language_provider.dart';

class LanguagePage extends StatefulWidget {
  final String currentLanguage;

  const LanguagePage({super.key, required this.currentLanguage});

  @override
  State<LanguagePage> createState() => _LanguagePageState();
}

class _LanguagePageState extends State<LanguagePage> {
  late String _selectedLanguage;
  final List<String> _languages = [
    'English',
    'Hindi',
    'Spanish',
    'French',
    'German',
  ];

  @override
  void initState() {
    super.initState();
    _selectedLanguage = widget.currentLanguage;
  }

  void _selectLanguage(String language) {
    setState(() {
      _selectedLanguage = language;
    });
    
    // Update global provider
    Provider.of<LanguageProvider>(context, listen: false).setLanguage(language);
    
    if (mounted) {
      Navigator.pop(context, language);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(Provider.of<LanguageProvider>(context).translate('language')),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: const TextStyle(
          color: Colors.blueAccent,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
        ),
        iconTheme: IconThemeData(color: colorScheme.onSurface),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _languages.length,
        itemBuilder: (context, index) {
          final language = _languages[index];
          final isSelected = _selectedLanguage == language;

          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: isSelected ? Colors.blueAccent : colorScheme.onSurface.withOpacity(0.1),
                width: isSelected ? 2 : 1,
              ),
            ),
            color: isSelected ? Colors.blueAccent.withOpacity(0.05) : colorScheme.surface,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              title: Text(
                language,
                style: TextStyle(
                  color: isSelected ? Colors.blueAccent : colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              trailing: isSelected
                  ? const Icon(Icons.check_circle, color: Colors.blueAccent)
                  : null,
              onTap: () => _selectLanguage(language),
            ),
          );
        },
      ),
    );
  }
}
