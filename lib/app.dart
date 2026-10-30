import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sanjay_roadlines_fleet/core/constants/app_colors.dart';
import 'package:sanjay_roadlines_fleet/core/constants/app_strings.dart';
import 'package:sanjay_roadlines_fleet/providers/auth_provider.dart';
import 'package:sanjay_roadlines_fleet/screens/auth/login_screen.dart';
import 'package:sanjay_roadlines_fleet/screens/auth/set_mpin_screen.dart';
import 'package:sanjay_roadlines_fleet/screens/admin/admin_dashboard.dart';
import 'package:sanjay_roadlines_fleet/screens/admin/notifications_screen.dart';
import 'package:sanjay_roadlines_fleet/screens/driver/driver_dashboard.dart';
import 'package:sanjay_roadlines_fleet/screens/admin/create_ticket_screen.dart';
import 'package:sanjay_roadlines_fleet/screens/admin/in_transit_screen.dart';
import 'package:sanjay_roadlines_fleet/screens/admin/completed_trips_screen.dart';
import 'package:sanjay_roadlines_fleet/screens/admin/vehicle_available_screen.dart';
import 'package:sanjay_roadlines_fleet/screens/admin/maintenance_screen.dart';
import 'package:sanjay_roadlines_fleet/screens/admin/reports_screen.dart';
import 'package:sanjay_roadlines_fleet/screens/admin/manage_drivers_screen.dart';
import 'package:sanjay_roadlines_fleet/screens/admin/manage_vehicles_screen.dart';
import 'package:sanjay_roadlines_fleet/screens/admin/assigned_tickets_screen.dart';
import 'package:sanjay_roadlines_fleet/screens/driver/assigned_ticket_screen.dart';
import 'package:sanjay_roadlines_fleet/screens/driver/ticket_detail_screen.dart';
import 'package:sanjay_roadlines_fleet/screens/driver/loading_form_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sanjay_roadlines_fleet/screens/driver/unloading_form_screen.dart';

// LANGUAGE PROVIDER
final languageProvider = StateProvider<Locale>((ref) => const Locale('en'));

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final listenable = _AuthStateListenable(ref);
  
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/login',
    refreshListenable: listenable,
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final user = authState.value;
      final isLoggingIn = state.matchedLocation == '/login';

      if (user == null) {
        return isLoggingIn ? null : '/login';
      }

      if (user.isFirstLogin) {
        return state.matchedLocation == '/set-mpin' ? null : '/set-mpin';
      }

      if (isLoggingIn || state.matchedLocation == '/set-mpin') {
        return user.role == 'admin' ? '/admin/dashboard' : '/driver/dashboard';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/set-mpin',
        builder: (context, state) => const SetMpinScreen(),
      ),
      GoRoute(
        path: '/admin/dashboard',
        builder: (context, state) => const AdminDashboard(),
      ),
      GoRoute(
        path: '/admin/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/admin/create-ticket',
        builder: (context, state) => const CreateTicketScreen(),
      ),
      GoRoute(
        path: '/admin/assigned-tickets',
        builder: (context, state) => const AdminAssignedTicketsScreen(),
      ),
      GoRoute(
        path: '/admin/in-transit',
        builder: (context, state) => const InTransitScreen(),
      ),
      GoRoute(
        path: '/admin/completed-trips',
        builder: (context, state) => const CompletedTripsScreen(),
      ),
      GoRoute(
        path: '/admin/vehicles-available',
        builder: (context, state) => const VehicleAvailableScreen(),
      ),
      GoRoute(
        path: '/admin/maintenance',
        builder: (context, state) => const MaintenanceScreen(),
      ),
      GoRoute(
        path: '/admin/reports',
        builder: (context, state) => const ReportsScreen(),
      ),
      GoRoute(
        path: '/admin/manage-drivers',
        builder: (context, state) => const ManageDriversScreen(),
      ),
      GoRoute(
        path: '/admin/manage-vehicles',
        builder: (context, state) => const ManageVehiclesScreen(),
      ),
      GoRoute(
        path: '/driver/dashboard',
        builder: (context, state) => const DriverDashboard(),
      ),
      GoRoute(
        path: '/driver/assigned-tickets',
        builder: (context, state) => const AssignedTicketScreen(),
      ),
      GoRoute(
        path: '/driver/ticket-detail/:ticketId',
        builder: (context, state) =>
            TicketDetailScreen(ticketId: state.pathParameters['ticketId']!),
      ),
      GoRoute(
        path: '/driver/loading-form/:ticketId',
        builder: (context, state) =>
            LoadingFormScreen(ticketId: state.pathParameters['ticketId']!),
      ),
      GoRoute(
        path: '/driver/unloading-form/:ticketId',
        builder: (context, state) =>
            UnloadingFormScreen(ticketId: state.pathParameters['ticketId']!),
      ),
    ],
  );
});

class App extends ConsumerStatefulWidget {
  final String initialLanguage;
  
  const App({super.key, this.initialLanguage = 'en'});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  @override
  void initState() {
    super.initState();
    // Set initial language from saved preference
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(languageProvider.notifier).state = Locale(widget.initialLanguage);
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final currentLocale = ref.watch(languageProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      title: AppStrings.appName,
      locale: currentLocale,
      theme: _chakkaSaarthiTheme(),
    );
  }
}

class _AuthStateListenable extends ChangeNotifier {
  _AuthStateListenable(Ref ref) {
    ref.listen(authStateProvider, (previous, next) {
      if (previous?.value != next.value || previous?.isLoading != next.isLoading) {
        notifyListeners();
      }
    });
  }
}

/// Chakka Saarthi theme: ink top bars, brand-yellow main buttons,
/// mist background, Space Grotesk font (from the brand kit).
ThemeData _chakkaSaarthiTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.ink,
      primary: AppColors.ink,
      onPrimary: Colors.white,
      secondary: AppColors.brandYellow,
      onSecondary: AppColors.onBrandYellow,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      error: AppColors.errorRed,
    ),
  );
  final textTheme = GoogleFonts.spaceGroteskTextTheme(base.textTheme).apply(
    bodyColor: AppColors.textPrimary,
    displayColor: AppColors.textPrimary,
  );
  return base.copyWith(
    primaryColor: AppColors.ink,
    scaffoldBackgroundColor: AppColors.background,
    textTheme: textTheme,
    dividerColor: AppColors.divider,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.ink,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.spaceGrotesk(
          fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.divider),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.brandYellow,
        foregroundColor: AppColors.onBrandYellow,
        elevation: 0,
        textStyle: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        side: const BorderSide(color: AppColors.ink, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.ink),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.brandYellow,
      foregroundColor: AppColors.onBrandYellow,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.ink, width: 2),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? AppColors.ink : null,
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.ink),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
