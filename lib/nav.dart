import 'package:go_router/go_router.dart';
import 'pages/home_page.dart';
import 'pages/session_setup_page.dart';
import 'pages/lecturer_dashboard_page.dart';
import 'pages/student_registration_page.dart';
import 'pages/signature_setup_page.dart';
import 'pages/cloud_login_page.dart';
import 'pages/cloud_sessions_page.dart';

/// GoRouter configuration for app navigation
class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      GoRoute(
        path: AppRoutes.home,
        name: 'home',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: HomePage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.setup,
        name: 'setup',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: SessionSetupPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.dashboard,
        name: 'dashboard',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: LecturerDashboardPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.register,
        name: 'register',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: StudentRegistrationPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.signature,
        name: 'signature',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: SignatureSetupPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.cloudLogin,
        name: 'cloudLogin',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: CloudLoginPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.cloudSessions,
        name: 'cloudSessions',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: CloudSessionsPage(),
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
}
