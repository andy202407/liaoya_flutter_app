import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/conversation_provider.dart';
import 'providers/friend_provider.dart';
import 'pages/auth/login_page.dart';
import 'pages/auth/register_page.dart';
import 'pages/home/home_page.dart';
import 'pages/splash/splash_page.dart';
import 'pages/chat/chat_page.dart';
import 'services/push_service.dart';

/// 全局 Navigator Key，用于在非 Widget 上下文中导航（如被踢下线时跳转登录页）
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // iOS 风格状态栏
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: Brightness.light,
    statusBarIconBrightness: Brightness.dark,
  ));

  // 初始化 JPush 推送（Android）
  await PushService.init();

  runApp(const LiaoyaApp());
}

class LiaoyaApp extends StatelessWidget {
  const LiaoyaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ConversationProvider()),
        ChangeNotifierProvider(create: (_) => FriendProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: '洽聊',
            debugShowCheckedModeBanner: false,
            navigatorKey: navigatorKey,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            // iOS 风格滚动行为
            scrollBehavior: const CupertinoScrollBehavior(),
            initialRoute: '/splash',
            routes: {
              '/splash': (_) => const SplashPage(),
              '/login': (_) => const LoginPage(),
              '/register': (_) => const RegisterPage(),
              '/home': (_) => const HomePage(),
            },
            onGenerateRoute: (settings) {
              if (settings.name == '/chat') {
                final conversation = settings.arguments as Map<String, dynamic>;
                return CupertinoPageRoute(
                  builder: (_) => ChatPage(conversation: conversation),
                );
              }
              return null;
            },
          );
        },
      ),
    );
  }
}
