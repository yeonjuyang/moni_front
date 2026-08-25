import 'package:dio/dio.dart';
import '../models/asset.dart';
import 'api_client.dart';

class AssetService {
  static Future<List<AssetModel>> fetchAssets({required int ledgerId}) async {
    final response = await ApiClient.dio.get('/api/ledgers/$ledgerId/assets');
    return (response.data as List)
        .map((json) => AssetModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  static Future<AssetModel> createAsset({
    required int ledgerId,
    required String assetName,
    required String assetType,
    required int balance,
  }) async {
    final response = await ApiClient.dio.post(
      '/api/ledgers/$ledgerId/assets',
      data: {
        'assetName': assetName,
        'assetType': assetType,
        'balance': balance,
      },
    );
    return AssetModel.fromJson(response.data as Map<String, dynamic>);
  }

  static Future<AssetModel> updateAsset({
    required int ledgerId,
    required int assetId,
    required String assetName,
    required String assetType,
    required int balance,
  }) async {
    final response = await ApiClient.dio.put(
      '/api/ledgers/$ledgerId/assets/$assetId',
      data: {
        'assetName': assetName,
        'assetType': assetType,
        'balance': balance,
      },
    );
    return AssetModel.fromJson(response.data as Map<String, dynamic>);
  }

  static Future<void> deleteAsset({
    required int ledgerId,
    required int assetId,
  }) async {
    await ApiClient.dio.delete('/api/ledgers/$ledgerId/assets/$assetId');
  }

  static Future<void> reorderAssets({
    required int ledgerId,
    required List<int> orderedIds,
  }) async {
    // Dio는 최상위가 리스트인 바디에는 Content-Type을 자동으로 붙이지
    // 않아서, 명시하지 않으면 서버가 파싱하지 못해 요청이 실패한다.
    await ApiClient.dio.put(
      '/api/ledgers/$ledgerId/assets/reorder',
      data: orderedIds,
      options: Options(contentType: Headers.jsonContentType),
    );
  }
}
