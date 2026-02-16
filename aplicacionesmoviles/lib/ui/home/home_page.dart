import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../recipes/recipes_tab.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final PageStorageBucket _bucket = PageStorageBucket();
  int _currentIndex = 0;
  bool _isSigningOut = false;

  List<_HomeDestination> get _destinations {
    final userEmail = AuthService.instance.currentUser?.email ?? 'tu cuenta';
    return <_HomeDestination>[
      _HomeDestination(
        title: 'Recetas',
        icon: Icons.restaurant_outlined,
        selectedIcon: Icons.restaurant,
        builder: (_) => const RecipesTab(),
      ),
      _HomeDestination(
        title: 'Favoritos',
        icon: Icons.favorite_border,
        selectedIcon: Icons.favorite,
        builder: (_) => const _PlaceholderTab(
          icon: Icons.favorite,
          title: 'Tus recetas favoritas',
          description:
              'Aquí podrás guardar y revisar tus preparaciones preferidas.',
        ),
      ),
      _HomeDestination(
        title: 'Perfil',
        icon: Icons.person_outline,
        selectedIcon: Icons.person,
        builder: (_) => _PlaceholderTab(
          icon: Icons.person,
          title: 'Tu perfil',
          description:
              'Configura tus preferencias y datos personales para $userEmail.',
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final destination = _destinations[_currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text(destination.title),
        actions: <Widget>[
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: _isSigningOut ? null : _confirmSignOut,
            icon: _isSigningOut
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout),
          ),
        ],
      ),
      body: PageStorage(
        bucket: _bucket,
        child: IndexedStack(
          index: _currentIndex,
          children: _destinations
              .map((destination) => destination.builder(context))
              .toList(growable: false),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (int index) {
          if (index == _currentIndex) {
            return;
          }
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: _destinations
            .map(
              (destination) => NavigationDestination(
                icon: Icon(destination.icon),
                selectedIcon: Icon(destination.selectedIcon),
                label: destination.title,
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  Future<void> _confirmSignOut() async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Cerrar sesión'),
          content: const Text('¿Quieres salir de tu cuenta actual?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Cerrar sesión'),
            ),
          ],
        );
      },
    );

    if (shouldSignOut != true) {
      return;
    }

    setState(() => _isSigningOut = true);
    await AuthService.instance.signOut();
    if (mounted) {
      setState(() => _isSigningOut = false);
    }
  }
}

class _HomeDestination {
  const _HomeDestination({
    required this.title,
    required this.icon,
    required this.selectedIcon,
    required this.builder,
  });

  final String title;
  final IconData icon;
  final IconData selectedIcon;
  final WidgetBuilder builder;
}

class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Icon(icon, size: 64, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 24),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
