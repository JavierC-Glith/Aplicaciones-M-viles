class Recipe {
  Recipe({
    required this.label,
    required this.imageUrl,
    required this.source,
    required this.url,
    required this.ingredients,
  });

  final String label;
  final String imageUrl;
  final String source;
  final String url;
  final List<String> ingredients;

  factory Recipe.fromJson(Map<String, dynamic> json) {
    final label = (json['strMeal'] as String?)?.trim() ?? 'Receta sin nombre';
    final imageUrl = (json['strMealThumb'] as String?)?.trim() ?? '';
    final category = (json['strCategory'] as String?)?.trim() ?? '';
    final area = (json['strArea'] as String?)?.trim() ?? '';

    final sourceParts = <String>[if (category.isNotEmpty) category, if (area.isNotEmpty) area];
    final source = sourceParts.isEmpty ? 'TheMealDB' : sourceParts.join(' • ');

    final urlCandidates = <String>[
      (json['strSource'] as String?)?.trim() ?? '',
      (json['strYoutube'] as String?)?.trim() ?? '',
    ];

    final idMeal = (json['idMeal'] as String?)?.trim();
    if (idMeal != null && idMeal.isNotEmpty) {
      urlCandidates.add('https://www.themealdb.com/meal/$idMeal');
    }

    final url = urlCandidates.firstWhere(
      (candidate) => candidate.isNotEmpty,
      orElse: () => '',
    );

    final ingredients = <String>[];
    for (int index = 1; index <= 20; index++) {
      final ingredient = (json['strIngredient$index'] as String?)?.trim() ?? '';
      final measure = (json['strMeasure$index'] as String?)?.trim() ?? '';
      if (ingredient.isEmpty) {
        continue;
      }

      final formattedIngredient = <String>[measure, ingredient]
          .where((value) => value.isNotEmpty)
          .join(' ');
      ingredients.add(formattedIngredient);
    }

    return Recipe(
      label: label,
      imageUrl: imageUrl,
      source: source,
      url: url,
      ingredients: List<String>.unmodifiable(ingredients),
    );
  }
}
