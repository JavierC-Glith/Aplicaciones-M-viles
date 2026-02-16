import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/themealdb_config.dart';
import '../models/recipe.dart';

class RecipeServiceException implements Exception {
  RecipeServiceException(this.message);

  final String message;

  @override
  String toString() => 'RecipeServiceException: $message';
}

class RecipeService {
  RecipeService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<Recipe>> searchRecipes(String query) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      return const <Recipe>[];
    }

    final uri = Uri.parse('${TheMealDbConfig.baseUrl}/search.php').replace(
      queryParameters: <String, String>{'s': normalizedQuery},
    );

    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw RecipeServiceException(
        'La API respondió con un error (${response.statusCode}).',
      );
    }

    final Map<String, dynamic> data =
        jsonDecode(response.body) as Map<String, dynamic>;
    final List<dynamic>? meals = data['meals'] as List<dynamic>?;

    if (meals == null) {
      return const <Recipe>[];
    }

    return meals
        .map((dynamic meal) {
          if (meal is! Map<String, dynamic>) {
            return null;
          }
          return Recipe.fromJson(meal);
        })
        .whereType<Recipe>()
        .toList(growable: false);
  }

  /// Búsqueda por lista de ingredientes. Usa filter.php?i= para cada
  /// ingrediente y luego obtiene los detalles de cada receta vía lookup.php?i=
  /// Se devuelve la unión de todas las recetas encontradas.
  Future<List<Recipe>> searchByIngredients(List<String> ingredients) async {
    final cleaned = ingredients.map((e) => e.trim()).where((e) => e.isNotEmpty).toList(growable: false);
    if (cleaned.isEmpty) return const <Recipe>[];

    // Conjunto de IDs de recetas encontradas por al menos un ingrediente.
    final Set<String> mealIds = <String>{};
    for (final ingredient in cleaned) {
      final uri = Uri.parse('${TheMealDbConfig.baseUrl}/filter.php').replace(
        queryParameters: <String, String>{'i': ingredient},
      );
      final response = await _client.get(uri);
      if (response.statusCode != 200) {
        // Ignoramos errores parciales, continuamos con otros ingredientes.
        continue;
      }
      final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
      final List<dynamic>? meals = data['meals'] as List<dynamic>?;
      if (meals == null) continue;
      for (final dynamic meal in meals) {
        if (meal is Map<String, dynamic>) {
          final idMeal = (meal['idMeal'] as String?)?.trim();
          if (idMeal != null && idMeal.isNotEmpty) {
            mealIds.add(idMeal);
          }
        }
      }
    }

    if (mealIds.isEmpty) return const <Recipe>[];

    // Obtener detalles completos de cada receta.
    final List<Recipe> results = <Recipe>[];
    for (final id in mealIds) {
      final detailUri = Uri.parse('${TheMealDbConfig.baseUrl}/lookup.php').replace(
        queryParameters: <String, String>{'i': id},
      );
      final detailResponse = await _client.get(detailUri);
      if (detailResponse.statusCode != 200) continue;
      final Map<String, dynamic> detailData = jsonDecode(detailResponse.body) as Map<String, dynamic>;
      final List<dynamic>? meals = detailData['meals'] as List<dynamic>?;
      if (meals == null || meals.isEmpty) continue;
      final dynamic meal = meals.first;
      if (meal is Map<String, dynamic>) {
        final recipe = Recipe.fromJson(meal);
        results.add(recipe);
      }
    }

    return results;
  }
}
