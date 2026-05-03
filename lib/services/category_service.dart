import '../models/category.dart';
import 'api_client.dart';

class CategoryService {
  static Future<List<CategoryModel>> fetchCategories({required int ledgerId}) async {
    final response = await ApiClient.dio.get('/api/ledgers/$ledgerId/categories');
    return (response.data as List)
        .map((json) => CategoryModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  static Future<CategoryModel> createCategory({
    required int ledgerId,
    required String categoryName,
    required String categoryType,
    required String iconName,
    required String iconColor,
  }) async {
    final response = await ApiClient.dio.post(
      '/api/ledgers/$ledgerId/categories',
      data: {
        'categoryName': categoryName,
        'categoryType': categoryType,
        'iconName': iconName,
        'iconColor': iconColor,
      },
    );
    return CategoryModel.fromJson(response.data as Map<String, dynamic>);
  }

  static Future<CategoryModel> updateCategory({
    required int ledgerId,
    required int categoryId,
    required String categoryName,
    required String categoryType,
    required String iconName,
    required String iconColor,
  }) async {
    final response = await ApiClient.dio.put(
      '/api/ledgers/$ledgerId/categories/$categoryId',
      data: {
        'categoryName': categoryName,
        'categoryType': categoryType,
        'iconName': iconName,
        'iconColor': iconColor,
      },
    );
    return CategoryModel.fromJson(response.data as Map<String, dynamic>);
  }

  static Future<void> deleteCategory({
    required int ledgerId,
    required int categoryId,
  }) async {
    await ApiClient.dio.delete('/api/ledgers/$ledgerId/categories/$categoryId');
  }
}
