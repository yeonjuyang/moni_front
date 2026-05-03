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
    await ApiClient.dio.put(
      '/api/ledgers/$ledgerId/assets/reorder',
      data: orderedIds,
    );
  }
}
