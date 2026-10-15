import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart'; 
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart'; 
import 'dart:io' show Platform;
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/router/app_router.dart';
import 'features/auth/providers/auth_provider.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (e) {}
  print("Arka planda bildirim geldi: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    if (Platform.isAndroid) {
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true, // Sesin çalmasına izin ver
      );
    }
  } catch (e) {
    print("Firebase Core hatası: $e");
  }

  runApp(
    ProviderScope(
      child: EasyLocalization(
        supportedLocales: const [
          Locale('tr'), Locale('en'), Locale('ru'), Locale('tk')
        ],
        path: 'assets/translations',
        fallbackLocale: const Locale('tr'),
        child: const HossarpayApp(),
      ),
    ),
  );
}

class HossarpayApp extends ConsumerStatefulWidget {
  const HossarpayApp({super.key});

  @override
  ConsumerState<HossarpayApp> createState() => _HossarpayAppState();
}

class _HossarpayAppState extends ConsumerState<HossarpayApp> {
  @override
  void initState() {
    super.initState();
    _setupFirebaseMessaging();
  }

  Future<void> _setupFirebaseMessaging() async {
    try {
      FirebaseMessaging messaging = FirebaseMessaging.instance;

      NotificationSettings settings = await messaging.requestPermission(
        alert: true, badge: true, sound: true, provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        String? fcmToken = await messaging.getToken();
        if (fcmToken != null) {
          ref.read(authProvider.notifier).setFCMToken(fcmToken);
        }

        messaging.onTokenRefresh.listen((newToken) {
          ref.read(authProvider.notifier).setFCMToken(newToken);
        });

        // YENİ: Bildirim gelince telefonda kendi sesini/titreşimini daha belirgin çaldırıyoruz
        FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
          if (message.notification != null) {
             String senderIdOrGroupId = message.data['senderId'] ?? message.data['groupId'] ?? '';
             bool isMuted = false;
             
             if (senderIdOrGroupId.isNotEmpty) {
               final prefs = await SharedPreferences.getInstance();
               isMuted = prefs.getBool('mute_$senderIdOrGroupId') ?? false;
             }
             
             if (!isMuted && mounted) {
               ScaffoldMessenger.of(context).showSnackBar(
                 SnackBar(
                   content: Column(
                     mainAxisSize: MainAxisSize.min,
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Text(message.notification!.title ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                       Text(message.notification!.body ?? ''),
                     ],
                   ),
                   backgroundColor: Theme.of(context).colorScheme.secondary,
                   duration: const Duration(seconds: 4),
                   behavior: SnackBarBehavior.floating,
                   margin: const EdgeInsets.only(top: 10, left: 10, right: 10),
                 ),
               );
             }
          }
        });
      }
    } catch (e) {
      print("FCM Setup Hatası: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Hossarpay',
      localizationsDelegates: [
        ...context.localizationDelegates,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      localeResolutionCallback: (locale, supportedLocales) {
        return locale;
      },
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: appRouter,
    );
  }
}