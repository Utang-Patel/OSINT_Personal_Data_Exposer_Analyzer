import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'services/translations.dart';

class LanguageProvider extends ChangeNotifier {
  Locale _currentLocale = const Locale('en');
  
  Locale get currentLocale => _currentLocale;

  String get currentLanguageName {
    final code = _currentLocale.languageCode;
    switch (code) {
      case 'hi': return 'Hindi';
      case 'es': return 'Spanish';
      case 'fr': return 'French';
      case 'de': return 'German';
      default: return 'English';
    }
  }

  LanguageProvider() {
    _loadSavedLanguage();
  }

  Future<void> _loadSavedLanguage() async {
    final apiService = ApiService();
    final language = await apiService.getLanguage();
    _currentLocale = Locale(_getLanguageCode(language));
    notifyListeners();
    }

  void setLanguage(String languageName) async {
    final code = _getLanguageCode(languageName);
    _currentLocale = Locale(code);
    notifyListeners();
    
    // Persist to API/Storage
    await ApiService().setLanguage(languageName);
  }

  String _getLanguageCode(String name) {
    switch (name.toLowerCase()) {
      case 'hindi': return 'hi';
      case 'spanish': return 'es';
      case 'french': return 'fr';
      case 'german': return 'de';
      default: return 'en';
    }
  }

  String translate(String key) {
    final languageCode = _currentLocale.languageCode;
    // Map code back to key name used in Translations.data
    String langKey = 'English';
    if (languageCode == 'hi') {
      langKey = 'Hindi';
    } else if (languageCode == 'es') langKey = 'Spanish';
    else if (languageCode == 'fr') langKey = 'French';
    else if (languageCode == 'de') langKey = 'German';

    return Translations.data[langKey]?[key] ?? Translations.data['English']?[key] ?? key;
  }
}
