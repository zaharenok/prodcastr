import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'session/session.dart';
import 'ui/tabs.dart';
import 'ui/onboarding.dart';
import 'ui/login.dart';
import 'ui/projects.dart';
import 'ui/board.dart';

void main() {
  runApp(const ProviderScope(child: ProdcastrApp()));
}

class ProdcastrApp extends ConsumerWidget {
  const ProdcastrApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Prodcastr',
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      final path = state.uri.path;

      if (!session.hasUrl) {
        return path == '/' ? null : '/';
      }
      if (!session.isAuthenticated) {
        return path == '/login' ? null : '/login';
      }
      // Authenticated: allow all app routes
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/projects',
            builder: (_, __) => const ProjectsScreen(),
          ),
          GoRoute(
            path: '/board/:projectId',
            builder: (context, state) => BoardScreen(
              projectId: state.pathParameters['projectId']!,
            ),
          ),
        ],
      ),
    ],
  );
});

/// App shell with the browser-like tab bar at the top and content below.
class AppShell extends ConsumerWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabs = ref.watch(tabProvider);
    final activeTabs = tabs.activeTabs;
    final router = GoRouter.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Prodcastr'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {},
            tooltip: 'Обновить',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(sessionProvider.notifier).signOut(),
            tooltip: 'Выйти',
          ),
        ],
      ),
      body: Column(
        children: [
          // === BROWSER-LIKE TAB BAR ===
          if (activeTabs.isNotEmpty)
            Container(
              height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.5),
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    width: 0.5,
                  ),
                ),
              ),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                itemCount: activeTabs.length,
                itemBuilder: (context, index) {
                  final tab = activeTabs[index];
                  final isActive = tab.project.id == tabs.activeTabId;

                  return GestureDetector(
                    onTap: () {
                      ref.read(tabProvider.notifier).setActiveTab(
                            tab.project.id,
                          );
                      router.go('/board/${tab.project.id}');
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: isActive
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isActive
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context)
                                  .colorScheme
                                  .outlineVariant,
                          width: isActive ? 1.5 : 0.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(tab.project.icon,
                              style: const TextStyle(fontSize: 12)),
                          const SizedBox(width: 4),
                          ConstrainedBox(
                            constraints:
                                const BoxConstraints(maxWidth: 100),
                            child: Text(
                              tab.project.name,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isActive
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: isActive
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context)
                                        .colorScheme
                                        .onSurface,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          // Close button (X)
                          GestureDetector(
                            onTap: () {
                              ref
                                  .read(tabProvider.notifier)
                                  .closeTab(tab.project.id);
                              // If no tabs left, go to projects list
                              if (ref.read(tabProvider).activeTabs.isEmpty) {
                                router.go('/projects');
                              }
                            },
                            child: Icon(
                              Icons.close,
                              size: 14,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          // === CONTENT AREA ===
          Expanded(child: child),
        ],
      ),
    );
  }
}
