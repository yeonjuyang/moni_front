import 'api_client.dart';

class UserModel {
  final int userId;
  final String nickname;

  const UserModel({required this.userId, required this.nickname});

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      userId: (json['userId'] as num).toInt(),
      nickname: json['nickname'] as String,
    );
  }
}

class UserService {
  static Future<List<UserModel>> fetchUsers() async {
    final response = await ApiClient.dio.get('/api/users');
    return (response.data as List)
        .map((json) => UserModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}
