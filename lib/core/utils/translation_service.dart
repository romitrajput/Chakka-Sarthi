import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Supported languages for the fleet app
class SupportedLanguage {
  final String code;
  final String name;
  final String nativeName;
  final TranslateLanguage mlKitLanguage;

  const SupportedLanguage({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.mlKitLanguage,
  });

  /// Get SupportedLanguage from code
  static SupportedLanguage? getLanguageFromCode(String code) {
    try {
      return supportedLanguages.firstWhere((lang) => lang.code == code);
    } catch (e) {
      return null;
    }
  }
}

/// Available languages for the fleet app
/// (Note: Malayalam and Punjabi are not supported by google_mlkit_translation v0.11)
const List<SupportedLanguage> supportedLanguages = [
  SupportedLanguage(
    code: 'en',
    name: 'English',
    nativeName: 'English',
    mlKitLanguage: TranslateLanguage.english,
  ),
  SupportedLanguage(
    code: 'hi',
    name: 'Hindi',
    nativeName: 'हिन्दी',
    mlKitLanguage: TranslateLanguage.hindi,
  ),
  SupportedLanguage(
    code: 'mr',
    name: 'Marathi',
    nativeName: 'मराठी',
    mlKitLanguage: TranslateLanguage.marathi,
  ),
  SupportedLanguage(
    code: 'gu',
    name: 'Gujarati',
    nativeName: 'ગુજરાતી',
    mlKitLanguage: TranslateLanguage.gujarati,
  ),
  SupportedLanguage(
    code: 'bn',
    name: 'Bengali',
    nativeName: 'বাংলা',
    mlKitLanguage: TranslateLanguage.bengali,
  ),
  SupportedLanguage(
    code: 'ta',
    name: 'Tamil',
    nativeName: 'தமிழ்',
    mlKitLanguage: TranslateLanguage.tamil,
  ),
  SupportedLanguage(
    code: 'te',
    name: 'Telugu',
    nativeName: 'తెలుగు',
    mlKitLanguage: TranslateLanguage.telugu,
  ),
  SupportedLanguage(
    code: 'kn',
    name: 'Kannada',
    nativeName: 'ಕನ್ನಡ',
    mlKitLanguage: TranslateLanguage.kannada,
  ),
  SupportedLanguage(
    code: 'ur',
    name: 'Urdu',
    nativeName: 'اردو',
    mlKitLanguage: TranslateLanguage.urdu,
  ),
];

/// Translation service using Google ML Kit for offline translation
class TranslationService {
  static final TranslationService _instance = TranslationService._internal();
  factory TranslationService() => _instance;
  TranslationService._internal();

  OnDeviceTranslator? _translator;
  TranslateLanguage _sourceLanguage = TranslateLanguage.english;
  TranslateLanguage _targetLanguage = TranslateLanguage.hindi;
  bool _isModelDownloaded = false;

  /// Current target language code
  String get currentLanguageCode => _getLanguageCode(_targetLanguage);

  /// Initialize the translator with source and target languages
  Future<void> initialize({
    required TranslateLanguage source,
    required TranslateLanguage target,
  }) async {
    _sourceLanguage = source;
    _targetLanguage = target;

    _translator?.close();
    _translator = OnDeviceTranslator(
      sourceLanguage: _sourceLanguage,
      targetLanguage: _targetLanguage,
    );

    // Check if model is downloaded
    _isModelDownloaded = await _checkModelDownloaded();
  }

  /// Check if the translation model is downloaded
  Future<bool> _checkModelDownloaded() async {
    try {
      final modelManager = OnDeviceTranslatorModelManager();
      final modelExists = await modelManager.isModelDownloaded(
        _targetLanguage.bcpCode,
      );
      return modelExists;
    } catch (e) {
      return false;
    }
  }

  /// Download the translation model for a language
  Future<bool> downloadModel(TranslateLanguage language) async {
    try {
      final modelManager = OnDeviceTranslatorModelManager();
      final success = await modelManager.downloadModel(language.bcpCode);
      return success;
    } catch (e) {
      return false;
    }
  }

  /// Check if a specific language model is downloaded
  Future<bool> isModelDownloaded(TranslateLanguage language) async {
    try {
      final modelManager = OnDeviceTranslatorModelManager();
      return await modelManager.isModelDownloaded(language.bcpCode);
    } catch (e) {
      return false;
    }
  }

  /// Translate text from source to target language
  Future<String> translate(String text) async {
    if (text.isEmpty) return text;

    // If target is English, no translation needed
    if (_targetLanguage == TranslateLanguage.english) {
      return text;
    }

    // Check if model is downloaded
    if (!_isModelDownloaded) {
      _isModelDownloaded = await _checkModelDownloaded();
      if (!_isModelDownloaded) {
        // Try to download the model
        _isModelDownloaded = await downloadModel(_targetLanguage);
      }
    }

    if (!_isModelDownloaded || _translator == null) {
      // Fallback: return original text if translation not available
      return text;
    }

    try {
      final translatedText = await _translator!.translateText(text);
      return translatedText;
    } catch (e) {
      // Fallback: return original text on error
      return text;
    }
  }

  /// Change target language
  Future<void> setTargetLanguage(TranslateLanguage language) async {
    if (language == _targetLanguage) return;

    // Dispose old translator
    _translator?.close();

    _targetLanguage = language;

    // Create new translator
    _translator = OnDeviceTranslator(
      sourceLanguage: _sourceLanguage,
      targetLanguage: _targetLanguage,
    );

    // Check/download model
    _isModelDownloaded = await _checkModelDownloaded();
    if (!_isModelDownloaded) {
      await downloadModel(_targetLanguage);
    }

    // Save preference
    await _saveLanguagePreference(_getLanguageCode(language));
  }

  /// Get language code from TranslateLanguage
  String _getLanguageCode(TranslateLanguage language) {
    final langMap = {
      TranslateLanguage.english: 'en',
      TranslateLanguage.hindi: 'hi',
      TranslateLanguage.marathi: 'mr',
      TranslateLanguage.gujarati: 'gu',
      TranslateLanguage.bengali: 'bn',
      TranslateLanguage.tamil: 'ta',
      TranslateLanguage.telugu: 'te',
      TranslateLanguage.kannada: 'kn',
      TranslateLanguage.urdu: 'ur',
    };
    return langMap[language] ?? 'en';
  }

  /// Save language preference
  Future<void> _saveLanguagePreference(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('translation_language', languageCode);
  }

  /// Load language preference
  Future<String> loadLanguagePreference() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('translation_language') ?? 'hi';
  }

  /// Dispose resources
  void dispose() {
    _translator?.close();
    _translator = null;
  }
}
