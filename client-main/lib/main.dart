import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'ui/pages/login/login_page.dart';
import 'ui/services/capsule_notification_service.dart';
import 'ui/services/push_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    await CapsuleNotificationService.initialize();
    await PushNotificationService.instance.initialize();
  }
  runApp(const KMemoryCapsuleApp());
}

class KMemoryCapsuleApp extends StatelessWidget {
  const KMemoryCapsuleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Capsule',
      theme: ThemeData(
        // 빛바랜 한지/종이 배경색
        scaffoldBackgroundColor: const Color(0xFFADD9F4),
        fontFamily: 'Workbench',
        useMaterial3: true,
      ),
      home: const LoginPage(),
    );
  }
}
