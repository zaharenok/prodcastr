import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/models.dart';
import '../api/kaneo_client.dart';
import '../session/session.dart';
import 'tabs.dart';

class ProjectsScreen extends ConsumerStatefulWidget {
  const ProjectsScreen({super.key});

  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends ConsumerState<ProjectsScreen> {
  List<Organization> _organizations = [];
  List<Project> _projects = [];
  String? _selectedOrgId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  KaneoClient? get _client => ref.read(kaneoClientProvider);

  Future<void> _loadData() async {
    if (_client == null) return;
    setState(() => _loading = true);
    try {
      _organizations = await _client!.listOrganizations();
      if (_organizations.isNotEmpty) {
        _selectedOrgId ??= _organizations.first.id;
        _projects = await _client!.listProjects(_selectedOrgId!);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки: $e')),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final tabs = ref.watch(tabProvider);
    final activeTabs = tabs.activeTabs;

    return Column(
      children: [
        // === BROWSER-LIKE TAB BAR ===
        if (activeTabs.isNotEmpty) _TabBar(activeTabs: activeTabs, tabsState: tabs),

        // === PROJECT LIST ===
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: _projects.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 80),
                            Center(
                              child: Text(
                                'Нет проектов',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _projects.length,
                          itemBuilder: (context, index) {
                            final project = _projects[index];
                            final isOpen = tabs.tabs.any(
                                (t) => t.project.id == project.id);
                            return _ProjectCard(
                              project: project,
                              isOpen: isOpen,
                              onTap: () {
                                ref.read(tabProvider.notifier).openTab(project);
                              },
                            );
                          },
                        ),
                ),
        ),
      ],
    );
  }
}

/// Browser-like horizontal tab bar showing only active (open) project tabs.
class _TabBar extends ConsumerWidget {
  final List<ProjectTab> activeTabs;
  final TabState tabsState;

  const _TabBar({required this.activeTabs, required this.tabsState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabNotifier = ref.read(tabProvider.notifier);

    return Container(
      height: 40,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        itemCount: activeTabs.length,
        itemBuilder: (context, index) {
          final tab = activeTabs[index];
          final isActive = tab.project.id == tabsState.activeTabId;

          return GestureDetector(
            onTap: () => tabNotifier.setActiveTab(tab.project.id),
            child: Container(
              margin: const EdgeInsets.only(right: 2),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isActive
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isActive
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outlineVariant,
                  width: isActive ? 1.5 : 0.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tab.project.icon,
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(width: 4),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 120),
                    child: Text(
                      tab.project.name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            isActive ? FontWeight.w600 : FontWeight.normal,
                        color: isActive
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Close button (X)
                  GestureDetector(
                    onTap: () {
                      tabNotifier.closeTab(tab.project.id);
                    },
                    child: Icon(
                      Icons.close,
                      size: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final Project project;
  final bool isOpen;
  final VoidCallback onTap;

  const _ProjectCard({
    required this.project,
    required this.isOpen,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final progress = project.statistics?.completionPercentage ?? 0;
    final total = project.statistics?.totalTasks ?? 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isOpen
            ? BorderSide(color: colorScheme.primary, width: 1.5)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text(project.icon, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      project.slug,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[500],
                          ),
                    ),
                    if (total > 0) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progress / 100,
                                minHeight: 6,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$progress%',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                isOpen ? Icons.tab : Icons.chevron_right,
                color: isOpen ? colorScheme.primary : Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
