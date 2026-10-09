import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/app_colors.dart';
import '../data/datasources/recipe_remote_datasource.dart';
import '../data/repositories/recipe_repository_impl.dart';
import '../domain/repositories/recipe_repository.dart';
import '../domain/usecases/get_personalized_feed.dart';
import 'home_feed/feed_cubit.dart';
import 'home_feed/home_feed_screen.dart';
import 'post_recipe/post_recipe_screen.dart';
import 'profile/profile_screen.dart';

// Shared ValueNotifier for managing navigation tab changes
final navigationTabNotifier = ValueNotifier<int>(0);

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  final List<GlobalKey<NavigatorState>> _tabNavigatorKeys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];

  final List<Widget> _screens = const [
    HomeFeedScreen(),
    PostRecipeScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Listen to navigation changes from other screens
    navigationTabNotifier.addListener(_handleTabChange);
  }

  void _handleTabChange() {
    setState(() {
      _currentIndex = navigationTabNotifier.value;
    });
  }

  @override
  void dispose() {
    navigationTabNotifier.removeListener(_handleTabChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider<RecipeRepository>(
      create: (_) => RecipeRepositoryImpl(
        remoteDataSource: RecipeRemoteDataSource(),
      ),
      child: BlocProvider(
        create: (context) {
        final cubit = FeedCubit(
          repository: context.read<RecipeRepository>(),
          personalizeFeed: GetPersonalizedFeed(),
        );
        cubit.start(Supabase.instance.client.auth.currentUser?.id ?? '');
        return cubit;
        },
        child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: List.generate(
            _screens.length,
            (index) => Navigator(
              key: _tabNavigatorKeys[index],
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (_) => _screens[index],
              ),
            ),
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            navigationTabNotifier.value = index;
            setState(() => _currentIndex = index);
          },
          backgroundColor: AppColors.surfaceWhite,
          indicatorColor: AppColors.secondaryPandan.withOpacity(0.15),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.add_circle_outline), selectedIcon: Icon(Icons.add_circle), label: 'Post a Recipe'),
            NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
        ),
      ),
    );
  }
}
