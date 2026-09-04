import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import '../../features/auth/providers/auth_provider.dart';
import 'package:go_router/go_router.dart';
import '../../features/onboarding/presentation/screens/splash_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/home/presentation/screens/main_layout.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/transfer/presentation/screens/transfer_screen.dart';
import '../../features/services/presentation/screens/services_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/admin/presentation/screens/admin_dashboard.dart';
import '../../features/history/presentation/screens/history_screen.dart';
import '../../features/chat/presentation/screens/chat_detail_screen.dart';
import '../../features/chat/presentation/screens/new_chat_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/tgLogin',
      builder: (context, state) {
        // Bu bos, tetikleyici bir ekran
        final tgId = state.uri.queryParameters['tgId'];
        final firstName = state.uri.queryParameters['firstName'];
        final lastName = state.uri.queryParameters['lastName'];
        final username = state.uri.queryParameters['username'];
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (tgId != null) {
             final container = ProviderScope.containerOf(context);
             container.read(authProvider.notifier).telegramLogin(tgId, firstName, lastName, username).then((_) {
               context.go('/home');
             });
          } else {
             context.go('/login');
          }
        });

        return Scaffold(
          backgroundColor: const Color(0xFF0F172A),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: Colors.blueAccent),
                const SizedBox(height: 16),
                const Text('Telegram ile güvenli giriş yapılıyor...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
          )
        );
      },
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => RegisterScreen(),
    ),
    GoRoute(
      path: '/admin',
      builder: (context, state) => const AdminDashboard(),
    ),
    // YENİ EKLENEN CHAT ROTALARI
    GoRoute(
      path: '/chat_detail',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return ChatDetailScreen(id: extra['id'], name: extra['name'], isGroup: extra['isGroup']);
      },
    ),
    GoRoute(
      path: '/new_chat',
      builder: (context, state) => const NewChatScreen(),
    ),
    GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
    GoRoute(path: '/transfer', builder: (context, state) => const TransferScreen()),
    GoRoute(path: '/services', builder: (context, state) => const ServicesScreen()),
    GoRoute(path: '/history', builder: (context, state) => const HistoryScreen()),
    GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
  ],
);
