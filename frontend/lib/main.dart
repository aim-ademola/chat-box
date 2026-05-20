import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/model/message_item_model.dart';
import 'package:frontend/provider/theme_provider.dart';
import 'package:frontend/screens/auth/login.dart';
import 'package:frontend/screens/auth/register.dart';
import 'package:frontend/screens/home/chat_detail.dart';
import 'package:frontend/screens/home/home_screen.dart';
import 'package:frontend/screens/home/upload_status.dart';
import 'package:frontend/screens/onboarding/onboard.dart';
import 'package:frontend/screens/onboarding/splash.dart';
import 'package:frontend/services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.initialize();
  runApp(ProviderScope(child: const MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: AppTheme().light,
      darkTheme: AppTheme().dark,
      themeMode: ref.watch(themeNotifierProvider),
      debugShowCheckedModeBanner: false,
      initialRoute: 'splash',
      routes: {
        'splash': (context) => SplashScreen(),
        'onboarding': (context) => OnboardingScreen(),
        'login': (_) => LoginScreen(),
        'register': (_) => RegisterScreen(),
        'home': (_) => HomeScreen(),
        'chat': (_) => ChatDetailScreen(
          contact: const MessageItemModel(
            name: 'Jhon Abraham',
            message: 'Hey! Can you join the meeting?',
            time: '2 min ago',
            initials: 'JA',
            avatarColor: Color(0xFFFFC94D),
            statusColor: Color(0xFF1EDB76),
            profilePicUrl:
                'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=600&q=80',
          ),
        ),
        'upload-status': (_) => UploadStatusScreen(),
      },
    );
  }
}
