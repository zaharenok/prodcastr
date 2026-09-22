/// Data models for Kaneo API responses.
library;

class KaneoUser {
  final String id;
  final String email;
  final String name;

  KaneoUser({required this.id, required this.email, required this.name});

  factory KaneoUser.fromJson(Map<String, dynamic> json) {
    return KaneoUser(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      name: json['name'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'email': email, 'name': name};
}

class Organization {
  final String id;
  final String name;
  final String slug;

  Organization({required this.id, required this.name, required this.slug});

  factory Organization.fromJson(Map<String, dynamic> json) {
    return Organization(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
    );
  }
}

class ProjectStats {
  final int completionPercentage;
  final int totalTasks;
  final String? dueDate;

  ProjectStats({
    required this.completionPercentage,
    required this.totalTasks,
    this.dueDate,
  });

  factory ProjectStats.fromJson(Map<String, dynamic> json) {
    return ProjectStats(
      completionPercentage: json['completionPercentage'] as int? ?? 0,
      totalTasks: json['totalTasks'] as int? ?? 0,
      dueDate: json['dueDate'] as String?,
    );
  }
}

class Project {
  final String id;
  final String workspaceId;
  final String slug;
  final String icon;
  final String name;
  final String? description;
  final int position;
  final int lastTaskNumber;
  final ProjectStats? statistics;

  Project({
    required this.id,
    required this.workspaceId,
    required this.slug,
    required this.icon,
    required this.name,
    this.description,
    required this.position,
    required this.lastTaskNumber,
    this.statistics,
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] as String? ?? '',
      workspaceId: json['workspaceId'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      icon: json['icon'] as String? ?? '📦',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      position: json['position'] as int? ?? 0,
      lastTaskNumber: json['lastTaskNumber'] as int? ?? 0,
      statistics: json['statistics'] != null
          ? ProjectStats.fromJson(json['statistics'] as Map<String, dynamic>)
          : null,
    );
  }
}

class BoardColumn {
  final String id;
  final String slug;
  final String name;
  final String icon;
  final bool isFinal;
  final List<BoardTask> tasks;

  BoardColumn({
    required this.id,
    required this.slug,
    required this.name,
    required this.icon,
    required this.isFinal,
    required this.tasks,
  });

  factory BoardColumn.fromJson(Map<String, dynamic> json) {
    return BoardColumn(
      id: json['id'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      name: json['name'] as String? ?? '',
      icon: json['icon'] as String? ?? '📋',
      isFinal: json['isFinal'] as bool? ?? false,
      tasks: (json['tasks'] as List<dynamic>?)
              ?.map((t) => BoardTask.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class BoardTask {
  final String id;
  final String title;
  final int number;
  final String? description;
  final String status;
  final String priority;
  final String? startDate;
  final String? dueDate;
  final int position;

  BoardTask({
    required this.id,
    required this.title,
    required this.number,
    this.description,
    required this.status,
    required this.priority,
    this.startDate,
    this.dueDate,
    required this.position,
  });

  factory BoardTask.fromJson(Map<String, dynamic> json) {
    return BoardTask(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      number: json['number'] as int? ?? 0,
      description: json['description'] as String?,
      status: json['status'] as String? ?? '',
      priority: json['priority'] as String? ?? 'no-priority',
      startDate: json['startDate'] as String?,
      dueDate: json['dueDate'] as String?,
      position: json['position'] as int? ?? 0,
    );
  }
}

class Board {
  final String id;
  final String name;
  final String icon;
  final List<BoardColumn> columns;

  Board({
    required this.id,
    required this.name,
    required this.icon,
    required this.columns,
  });

  factory Board.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    return Board(
      id: data['id'] as String? ?? '',
      name: data['name'] as String? ?? '',
      icon: data['icon'] as String? ?? '📋',
      columns: (data['columns'] as List<dynamic>?)
              ?.map((c) => BoardColumn.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
