import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdown_widget/markdown_widget.dart';
import '../api/models.dart';
import '../api/kaneo_client.dart';
import '../session/session.dart';

class BoardScreen extends ConsumerStatefulWidget {
  final String projectId;

  const BoardScreen({super.key, required this.projectId});

  @override
  ConsumerState<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends ConsumerState<BoardScreen> {
  Board? _board;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBoard();
  }

  @override
  void didUpdateWidget(covariant BoardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.projectId != widget.projectId) {
      _loadBoard();
    }
  }

  KaneoClient? get _client => ref.read(kaneoClientProvider);

  Future<void> _loadBoard() async {
    if (_client == null) return;
    setState(() => _loading = true);
    try {
      _board = await _client!.board(widget.projectId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки доски: $e')),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _createTask(String columnSlug) async {
    final titleController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Новая задача'),
        content: TextField(
          controller: titleController,
          decoration: const InputDecoration(
            labelText: 'Заголовок',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, titleController.text.trim()),
            child: const Text('Создать'),
          ),
        ],
      ),
    );
    if (result == null || result.isEmpty || _client == null) return;
    try {
      await _client!.createTask(widget.projectId, result, columnSlug);
      await _loadBoard();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }

  Future<void> _showTaskDetail(BoardTask task) async {
    final columns = _board?.columns ?? [];
    final currentStatus = task.status;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (ctx, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '#${task.number} ${task.title}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              // Priority chip
              Chip(
                avatar: Icon(
                  _priorityIcon(task.priority),
                  size: 16,
                ),
                label: Text(_priorityLabel(task.priority)),
              ),
              const SizedBox(height: 16),
              // Status selector
              const Text('Статус:',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: columns.map((col) {
                  final isSelected = col.slug == currentStatus;
                  return ChoiceChip(
                    label: Text('${col.icon} ${col.name}'),
                    selected: isSelected,
                    onSelected: isSelected
                        ? null
                        : (_) async {
                            final client = _client;
                            if (client == null) return;
                            try {
                              await client.setTaskStatus(task.id, col.slug);
                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                              }
                              if (mounted) {
                                _loadBoard();
                              }
                            } catch (e) {
                              if (!mounted) return;
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Ошибка: $e')),
                                );
                              }
                            }
                          },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              // Priority selector
              const Text('Приоритет:',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ['no-priority', 'low', 'medium', 'high', 'urgent']
                    .map((p) {
                  final isSelected = p == task.priority;
                  return ChoiceChip(
                    avatar: Icon(_priorityIcon(p), size: 16),
                    label: Text(_priorityLabel(p)),
                    selected: isSelected,
                    onSelected: isSelected
                        ? null
                        : (_) async {
                            final client = _client;
                            if (client == null) return;
                            try {
                              await client.setTaskPriority(task.id, p);
                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                              }
                              if (mounted) {
                                _loadBoard();
                              }
                            } catch (e) {
                              if (!mounted) return;
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Ошибка: $e')),
                                );
                              }
                            }
                          },
                  );
                }).toList(),
              ),
              // Description
              if (task.description != null &&
                  task.description!.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text('Описание:',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                MarkdownBlock(data: task.description!),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _priorityLabel(String p) {
    switch (p) {
      case 'low':
        return 'Низкий';
      case 'medium':
        return 'Средний';
      case 'high':
        return 'Высокий';
      case 'urgent':
        return 'Срочный';
      default:
        return 'Без';
    }
  }

  IconData _priorityIcon(String p) {
    switch (p) {
      case 'low':
        return Icons.arrow_downward;
      case 'medium':
        return Icons.remove;
      case 'high':
        return Icons.arrow_upward;
      case 'urgent':
        return Icons.warning;
      default:
        return Icons.horizontal_rule;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_board == null) {
      return const Center(child: Text('Не удалось загрузить доску'));
    }

    return RefreshIndicator(
      onRefresh: _loadBoard,
      child: PageView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _board!.columns.length,
        itemBuilder: (context, colIndex) {
          final column = _board!.columns[colIndex];
          return Column(
            children: [
              // Column header
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Text(column.icon, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Text(
                      '${column.name} (${column.tasks.length})',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.add, size: 20),
                      onPressed: () => _createTask(column.slug),
                    ),
                  ],
                ),
              ),
              // Task list
              Expanded(
                child: column.tasks.isEmpty
                    ? const Center(
                        child: Text('Нет задач',
                            style: TextStyle(color: Colors.grey)),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: column.tasks.length,
                        itemBuilder: (context, taskIndex) {
                          final task = column.tasks[taskIndex];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(
                                '#${task.number} ${task.title}',
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                              subtitle: task.priority != 'no-priority'
                                  ? Chip(
                                      avatar: Icon(
                                        _priorityIcon(task.priority),
                                        size: 14,
                                      ),
                                      label: Text(_priorityLabel(task.priority)),
                                      visualDensity: VisualDensity.compact,
                                      padding: EdgeInsets.zero,
                                    )
                                  : null,
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => _showTaskDetail(task),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
