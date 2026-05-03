import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // 카카오 개발자 콘솔에서 발급받은 네이티브 앱 키로 교체
  KakaoSdk.init(nativeAppKey: '');
  runApp(const MoniApp());
}

class MoniApp extends StatelessWidget {
  const MoniApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Moni',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF4361EE),
      ),
      home: const SplashScreen(),
    );
  }
}
