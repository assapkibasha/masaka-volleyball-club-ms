import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/session/auth_controller.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/dashboard/screens/dashboard_screen.dart';
import 'features/members/screens/all_members_screen.dart';
import 'features/members/screens/member_profile_screen.dart';
import 'features/members/screens/register_member_screen.dart';
import 'features/finance/screens/contributions_screen.dart';
import 'features/finance/screens/unpaid_members_screen.dart';
import 'features/notifications/screens/notifications_screen.dart';
import 'features/reports/screens/reports_screen.dart';
import 'features/settings/screens/settings_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authController = ref.read(authControllerProvider);

  return GoRouter(
    initialLocation: authController.isAuthenticated ? '/dashboard' : '/login',
    refreshListenable: authController,
    redirect: (context, state) {
      final isAuthenticated = authController.isAuthenticated;
      final isLoginRoute = state.matchedLocation == '/login';

      if (!isAuthenticated && !isLoginRoute) {
        return '/login';
      }

      if (isAuthenticated && isLoginRoute) {
        return '/dashboard';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/dashboard', builder: (context, state) => const DashboardScreen()),
      GoRoute(path: '/members', builder: (context, state) => const AllMembersScreen()),
      GoRoute(
        path: '/members/:memberId',
        builder: (context, state) => MemberProfileScreen(memberId: state.pathParameters['memberId']!),
      ),
      GoRoute(path: '/register-member', builder: (context, state) => const RegisterMemberScreen()),
      GoRoute(path: '/contributions', builder: (context, state) => const ContributionsScreen()),
      GoRoute(path: '/unpaid-members', builder: (context, state) => const UnpaidMembersScreen()),
      GoRoute(path: '/notifications', builder: (context, state) => const NotificationsScreen()),
      GoRoute(path: '/reports', builder: (context, state) => const ReportsScreen()),
      GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
    ],
  );
});
