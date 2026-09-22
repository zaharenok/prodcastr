import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/models.dart';

/// An open tab representing a project the user has opened.
class ProjectTab {
  final Project project;
  final bool isActive;

  const ProjectTab({required this.project, this.isActive = true});

  ProjectTab copyWith({bool? isActive}) {
    return ProjectTab(project: project, isActive: isActive ?? this.isActive);
  }
}

/// Manages open project tabs — like browser tabs.
/// Only active projects are shown in the tab bar.
class TabState {
  final List<ProjectTab> tabs;
  final String? activeTabId;

  const TabState({this.tabs = const [], this.activeTabId});

  TabState copyWith({List<ProjectTab>? tabs, String? activeTabId}) {
    return TabState(
      tabs: tabs ?? this.tabs,
      activeTabId: activeTabId ?? this.activeTabId,
    );
  }

  List<ProjectTab> get activeTabs =>
      tabs.where((t) => t.isActive).toList();

  ProjectTab? get activeTab =>
      tabs.cast<ProjectTab?>().firstWhere((t) => t?.project.id == activeTabId,
          orElse: () => null);
}

class TabNotifier extends StateNotifier<TabState> {
  TabNotifier() : super(const TabState());

  /// Open a project as a tab. If already open, just make it active.
  void openTab(Project project) {
    final existing = state.tabs
        .where((t) => t.project.id == project.id)
        .toList();
    if (existing.isNotEmpty) {
      // Already open — just activate it
      state = state.copyWith(activeTabId: project.id);
    } else {
      state = TabState(
        tabs: [...state.tabs, ProjectTab(project: project)],
        activeTabId: project.id,
      );
    }
  }

  /// Close a tab (collapse it). If it was active, switch to the nearest tab.
  void closeTab(String projectId) {
    final idx = state.tabs.indexWhere((t) => t.project.id == projectId);
    if (idx == -1) return;

    final newTabs = [...state.tabs]..removeAt(idx);

    String? newActiveId = state.activeTabId;
    if (state.activeTabId == projectId) {
      // Switch to nearest: previous tab, or next, or null
      if (newTabs.isNotEmpty) {
        final nextIdx = idx > 0 ? idx - 1 : 0;
        newActiveId = nextIdx >= 0 ? newTabs[nextIdx].project.id : null;
      } else {
        newActiveId = null;
      }
    }

    state = TabState(tabs: newTabs, activeTabId: newActiveId);
  }

  /// Switch the active tab.
  void setActiveTab(String projectId) {
    state = TabState(tabs: state.tabs, activeTabId: projectId);
  }
}

final tabProvider = StateNotifierProvider<TabNotifier, TabState>((ref) {
  return TabNotifier();
});
