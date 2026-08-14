import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  // 네이버 개발자 센터에서 발급받은 값으로 교체
  static const String _naverClientId = "";
  static const String _naverClientSecret = "";
  static const String _naverRedirectUri = "";
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
    await _saveSession(jwt: jwt, provider: 'naver');
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
    await _saveSession(jwt: jwt, provider: 'kakao');
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
    await _saveSession(jwt: jwt, provider: 'dev');
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
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', jwt);
    await prefs.setString('login_provider', provider);
    await prefs.setBool('is_logged_in', true);
  }

  static String _generateState() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }
}
