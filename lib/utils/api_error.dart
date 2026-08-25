import 'package:dio/dio.dart';

/// 서버가 내려준 에러 메시지가 있으면 그걸 쓰고, 없으면 일반적인 문구로
/// 대체한다. DioException을 그대로 문자열로 찍으면 상태 코드 설명 같은
/// 개발자용 텍스트가 사용자에게 그대로 노출된다.
String friendlyError(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['error'] is String) {
      return data['error'] as String;
    }
    return '요청을 처리하지 못했어요. 잠시 후 다시 시도해주세요.';
  }
  return error.toString();
}
