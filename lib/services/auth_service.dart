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
