import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  // 네이버 개발자 센터에서 발급받은 Client ID로 교체 (Client Secret은 백엔드에만 둔다 — 앱 바이너리는 디컴파일 가능)
  static const String _naverClientId = "p1u4Ad75CEdISzBsm_EC";

  // 네이버 개발자센터 콜백 URL은 http(s)만 허용된다.
  // - 앱(모바일/데스크톱): 백엔드 패스스루가 code를 moni://naver_callback 로 다시 리다이렉트해준다.
  // - 웹: flutter_web_auth_2가 같은 origin의 정적 페이지로만 돌아올 수 있어 백엔드를 거치지 않는다.
  //   `flutter run -d chrome --web-port=5000` 처럼 포트를 고정해서 실행해야 이 값과 일치한다.
  static const String _naverRedirectUriApp = "http://localhost:8080/api/auth/naver/callback";
  static const String _naverRedirectUriWeb = "http://localhost:5000/naver_callback.html";
  static String get _naverRedirectUri => kIsWeb ? _naverRedirectUriWeb : _naverRedirectUriApp;
  static const String _callbackScheme = "moni";

  static const String _baseUrl = 'http://localhost:8080';
  static final Dio _dio = Dio(BaseOptions(baseUrl: _baseUrl));

  static Future<void> loginWithNaver() async {
    final state = _generateState();

    final authUrl = Uri.https('nid.naver.com', '/oauth2.0/authorize', {
      'response_type': 'code',
      'client_id': _naverClientId,
      'redirect_uri': _naverRedirectUri,
      'state': state,
    });

    final result = await FlutterWebAuth2.authenticate(
      url: authUrl.toString(),
      callbackUrlScheme: _callbackScheme,
    );

    final uri = Uri.parse(result);
    final code = uri.queryParameters['code'];
    final returnedState = uri.queryParameters['state'];

    if (code == null || returnedState != state) {
      throw Exception('인증 실패: state 불일치');
    }

    final response = await _dio.post(
      '/api/auth/naver',
      queryParameters: {'code': code},
    );

    final jwt = response.data['token'] as String;
    final nickname = response.data['nickname'] as String?;
    await _saveSession(jwt: jwt, provider: 'naver', nickname: nickname);
  }

  static Future<void> loginWithKakao() async {
    OAuthToken token;

    // 카카오톡 설치 여부에 따라 로그인 방식 분기
    if (await isKakaoTalkInstalled()) {
      token = await UserApi.instance.loginWithKakaoTalk();
    } else {
      token = await UserApi.instance.loginWithKakaoAccount();
    }

    final response = await _dio.post(
      '/api/auth/kakao',
      queryParameters: {'accessToken': token.accessToken},
    );

    final jwt = response.data['token'] as String;
    final nickname = response.data['nickname'] as String?;
    await _saveSession(jwt: jwt, provider: 'kakao', nickname: nickname);
  }

  // 카카오/네이버 개발자 앱 키 발급 전까지 사용하는 임시 로그인.
  // data.sql에 미리 심어둔 테스트 계정(test@test.com, partner@test.com)으로 로그인해
  // 공유 가계부 등 다중 사용자 흐름을 미리 검증할 수 있다.
  static Future<void> loginDev({required String email, required String nickname}) async {
    final response = await _dio.post(
      '/api/auth/dev-login',
      data: {'email': email, 'nickname': nickname},
    );

    final jwt = response.data['token'] as String;
    final savedNickname = response.data['nickname'] as String?;
    await _saveSession(jwt: jwt, provider: 'dev', nickname: savedNickname);
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final provider = prefs.getString('login_provider');

    if (provider == 'kakao') {
      await UserApi.instance.logout();
    }
    // 네이버, 애플은 로컬 세션 삭제만으로 충분

    await prefs.remove('jwt_token');
    await prefs.remove('login_provider');
    await prefs.setBool('is_logged_in', false);
  }

  static Future<void> _saveSession({
    required String jwt,
    required String provider,
    String? nickname,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', jwt);
    await prefs.setString('login_provider', provider);
    await prefs.setBool('is_logged_in', true);
    if (nickname != null && nickname.isNotEmpty) {
      await prefs.setString('user_nickname', nickname);
    }
  }

  static String _generateState() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }
}
