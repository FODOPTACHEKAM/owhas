import 'package:go_router/go_router.dart';
// ── Feature screens (new architecture) ───────────────────────────────────────
import 'features/home/screens/home_screen.dart';
import 'features/session/screens/session_setup_screen.dart';
import 'features/session/screens/lecturer_dashboard_screen.dart';
import 'features/attendance/screens/student_registration_screen.dart';
import 'features/catalogue/screens/course_catalogue_screen.dart';
import 'features/cloud/screens/cloud_sessions_screen.dart';
import 'features/signature/screens/signature_setup_screen.dart';
import 'features/cloud/screens/cloud_login_screen.dart';

/// GoRouter configuration for app navigation
class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      GoRoute(
        path: AppRoutes.home,
        name: 'home',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: HomeScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.setup,
        name: 'setup',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: SessionSetupScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.dashboard,
        name: 'dashboard',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: LecturerDashboardScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.register,
        name: 'register',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: StudentRegistrationScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.signature,
        name: 'signature',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: SignatureSetupScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.cloudLogin,
        name: 'cloudLogin',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: CloudLoginScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.cloudSessions,
        name: 'cloudSessions',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: CloudSessionsScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.catalogue,
        name: 'catalogue',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: CourseCatalogueScreen(),
        ),
      ),
    ],
  );
}

/// Route path constants
class AppRoutes {
  static const String home = '/';
  static const String setup = '/setup';
  static const String dashboard = '/dashboard';
  static const String register = '/register';
  static const String signature = '/signature';
  static const String cloudLogin = '/cloud-login';
  static const String cloudSessions = '/cloud-sessions';
  static const String catalogue = '/catalogue';
}
