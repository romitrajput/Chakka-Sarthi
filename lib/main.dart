import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sanjay_roadlines_fleet/core/constants/supabase_constants.dart';
import 'package:sanjay_roadlines_fleet/core/constants/app_translations.dart';
import 'package:sanjay_roadlines_fleet/core/utils/local_notification_service.dart';
import 'package:sanjay_roadlines_fleet/core/utils/translation_service.dart';
import 'package:sanjay_roadlines_fleet/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConstants.supabaseUrl,
    publishableKey: SupabaseConstants.supabaseAnonKey,
  );

  // Initialize local notifications
  await LocalNotificationService.initialize();

  // Load saved language preference
  final savedLanguage = await AppTranslations.loadLanguage();
  
  // Initialize translation service for ML Kit
  final translationService = TranslationService();
  final savedLang = SupportedLanguage.getLanguageFromCode(savedLanguage);
  if (savedLang != null) {
    await translationService.initialize(
      source: SupportedLanguage.getLanguageFromCode('en')!.mlKitLanguage,
      target: savedLang.mlKitLanguage,
    );
    // Initialize notification translation
    await LocalNotificationService.initializeTranslation(
      targetLanguageCode: savedLanguage,
    );
  }

  runApp(
    ProviderScope(
      child: SanjayRoadlinesApp(initialLanguage: savedLanguage),
    ),
  );
}

class SanjayRoadlinesApp extends StatelessWidget {
  final String initialLanguage;
  
  const SanjayRoadlinesApp({super.key, this.initialLanguage = 'en'});

  @override
  Widget build(BuildContext context) {
    return App(initialLanguage: initialLanguage);
  }
}
