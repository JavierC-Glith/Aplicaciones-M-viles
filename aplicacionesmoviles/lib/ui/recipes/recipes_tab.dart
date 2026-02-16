import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/recipe.dart';
import '../../services/recipe_service.dart';
import '../../services/auth_service.dart';

class RecipesTab extends StatefulWidget {
  const RecipesTab({super.key});

  @override
  State<RecipesTab> createState() => _RecipesTabState();
}

class _RecipesTabState extends State<RecipesTab> {
  final RecipeService _service = RecipeService();
  final TextEditingController _ingredientController = TextEditingController();

  // Lista única de resultados filtrados y ordenados por coincidencias
  final List<Recipe> _matchedRecipes = <Recipe>[];
  final List<String> _ingredients = <String>[];
  bool _hasSearched = false;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _ingredientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            _buildGreeting(),
            const SizedBox(height: 20),
            _buildIngredientPrompt(context),
            const SizedBox(height: 16),
            _buildIngredientList(),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _isLoading ? null : _searchRecipes,
                icon: const Icon(Icons.search),
                label: const Text('Buscar recetas'),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildGreeting() {
    final email = AuthService.instance.currentUser?.email;
    final username = email?.split('@').first ?? 'Chef';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '¡Hola, $username! 👋',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Cuéntanos qué ingredientes tienes hoy y buscaremos recetas a tu medida.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildIngredientPrompt(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: TextField(
            controller: _ingredientController,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _addIngredient(),
            decoration: const InputDecoration(
              labelText: '¿Qué ingredientes tienes hoy?',
              hintText: 'Ej. pollo, tomate, cebolla',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 12),
        IconButton(
          tooltip: 'Agregar ingrediente',
          onPressed: _addIngredient,
          icon: const Icon(Icons.add_circle_outline),
          color: Theme.of(context).colorScheme.primary,
          iconSize: 28,
        ),
      ],
    );
  }

  Widget _buildIngredientList() {
    if (_ingredients.isEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Agrega los ingredientes y podrás eliminarlos si cambias de opinión.',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: Colors.grey.shade700),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _ingredients
            .map(
              (ingredient) => Chip(
                label: Text(ingredient),
                deleteIcon: const Icon(Icons.close),
                onDeleted: () => _removeIngredient(ingredient),
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _ErrorView(
        message: _error!,
        onRetry: _searchRecipes,
      );
    }

    if (!_hasSearched) {
      return const _EmptyView(
        message:
            'Empieza añadiendo ingredientes para encontrar la receta perfecta.',
      );
    }

    if (_matchedRecipes.isEmpty) {
      return const _EmptyView(
        message: 'No encontramos recetas que usen esos ingredientes.',
      );
    }

    return ListView.separated(
      key: const PageStorageKey<String>('recipes_list'),
      itemCount: _matchedRecipes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (BuildContext context, int index) {
        final recipe = _matchedRecipes[index];
        final matches = _countMatches(recipe);
        final label = matches == 1
            ? '1 coincidencia'
            : '$matches coincidencias';
        return _RecipeCard(
          recipe: recipe,
          onTap: () => _showRecipeDetails(recipe),
          badgeLabel: label,
        );
      },
    );
  }

  Future<void> _searchRecipes() async {
    FocusScope.of(context).unfocus();
    if (_ingredients.isEmpty) {
      setState(() {
        _error = 'Agrega al menos un ingrediente para empezar la búsqueda.';
        _hasSearched = true;
        _matchedRecipes.clear();
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _hasSearched = true;
      _matchedRecipes.clear();
    });

    try {
      // Usamos la nueva búsqueda por ingredientes en lugar de búsqueda por nombre.
      final recipes = await _service.searchByIngredients(_ingredients);
      if (!mounted) {
        return;
      }
      _sortRecipes(recipes);
    } on RecipeServiceException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Ocurrió un error inesperado. Inténtalo nuevamente.';
      });
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _sortRecipes(List<Recipe> recipes) {
    // Mantener solo recetas con al menos 1 coincidencia y ordenar por #coincidencias desc.
    final matched = recipes.where((r) => _countMatches(r) > 0).toList();
    matched.sort((a, b) => _countMatches(b).compareTo(_countMatches(a)));
    setState(() {
      _matchedRecipes
        ..clear()
        ..addAll(matched);
    });
  }

  int _countMatches(Recipe recipe) {
    final normalizedRecipeIngredients = recipe.ingredients
        .map((ingredient) => ingredient.toLowerCase())
        .toList(growable: false);
    int count = 0;
    for (final ingredient in _ingredients) {
      final ing = ingredient.toLowerCase();
      if (normalizedRecipeIngredients.any((ri) => ri.contains(ing))) {
        count++;
      }
    }
    return count;
  }

  void _addIngredient() {
    final rawValue = _ingredientController.text.trim();
    if (rawValue.isEmpty) {
      return;
    }

    final normalizedValue = rawValue.toLowerCase();
    if (_ingredients.contains(normalizedValue)) {
      _ingredientController.clear();
      return;
    }

    setState(() {
      _ingredients.add(normalizedValue);
      _error = null;
    });
    _ingredientController.clear();
  }

  void _removeIngredient(String ingredient) {
    setState(() {
      _ingredients.remove(ingredient);
    });
  }

  void _showRecipeDetails(Recipe recipe) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          expand: false,
          builder: (BuildContext context, ScrollController controller) {
            return ListView(
              controller: controller,
              padding: const EdgeInsets.all(24),
              children: <Widget>[
                Text(
                  recipe.label,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Fuente: ${recipe.source}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                if (recipe.imageUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      recipe.imageUrl,
                      fit: BoxFit.cover,
                      height: 200,
                      width: double.infinity,
                      errorBuilder: (context, error, stackTrace) =>
                          const SizedBox.shrink(),
                    ),
                  ),
                const SizedBox(height: 24),
                Text(
                  'Ingredientes',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ..._buildIngredientItems(recipe.ingredients),
                const SizedBox(height: 24),
                if (recipe.url.isNotEmpty)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _openRecipeUrl(recipe.url),
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Ver receta completa'),
                    ),
                  ),
                SizedBox(height: MediaQuery.of(context).padding.bottom),
              ],
            );
          },
        );
      },
    );
  }

  List<Widget> _buildIngredientItems(List<String> ingredients) {
    if (ingredients.isEmpty) {
      return <Widget>[const Text('No se encontraron ingredientes.')];
    }

    final List<Widget> items = <Widget>[];
    for (int index = 0; index < ingredients.length; index++) {
      items.add(Text('• ${ingredients[index]}'));
      if (index < ingredients.length - 1) {
        items.add(const Divider(height: 16));
      }
    }
    return items;
  }

  Future<void> _openRecipeUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      _showSnackBar('El enlace de la receta no es válido.');
      return;
    }

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _showSnackBar('No pudimos abrir el enlace de la receta.');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _RecipeCard extends StatelessWidget {
  const _RecipeCard({
    required this.recipe,
    required this.onTap,
    this.badgeLabel,
  });

  final Recipe recipe;
  final VoidCallback onTap;
  final String? badgeLabel;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _RecipeImage(imageUrl: recipe.imageUrl),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (badgeLabel != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              Icons.eco_outlined,
                              size: 16,
                              color: Colors.black87,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              badgeLabel!,
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    if (badgeLabel != null) const SizedBox(height: 8),
                    Text(
                      recipe.label,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      recipe.source,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${recipe.ingredients.length} ingredientes',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// _SectionHeader eliminado por no utilizarse en la nueva UI

class _RecipeImage extends StatelessWidget {
  const _RecipeImage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      height: 84,
      width: 84,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.restaurant, size: 32, color: Colors.grey),
    );

    if (imageUrl.isEmpty) {
      return placeholder;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        imageUrl,
        height: 84,
        width: 84,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => placeholder,
        loadingBuilder: (
          BuildContext context,
          Widget child,
          ImageChunkEvent? loadingProgress,
        ) {
          if (loadingProgress == null) {
            return child;
          }
          return SizedBox(
            height: 84,
            width: 84,
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({
    this.message = 'No encontramos recetas para tu búsqueda.',
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(Icons.search_off, size: 48, color: Colors.grey.shade600),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              message,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              message,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}
