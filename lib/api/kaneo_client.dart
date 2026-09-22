import 'package:dio/dio.dart';
import 'models.dart';

class KaneoClient {
  final Dio dio;
  String? _token;

  KaneoClient(String baseUrl)
      : dio = Dio(BaseOptions(
          baseUrl: '$baseUrl/api',
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
          validateStatus: (status) => status != null && status < 500,
        )) {
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_token != null) {
          options.headers['Authorization'] = 'Bearer $_token';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        if (error.response?.statusCode == 401) {
          _token = null;
        }
        handler.next(error);
      },
    ));
  }

  void setToken(String? token) => _token = token;

  // Auth
  Future<Map<String, dynamic>> signIn(String email, String password) async {
    final resp = await dio.post('/auth/sign-in/email', data: {
      'email': email,
      'password': password,
    });
    return resp.data as Map<String, dynamic>;
  }

  // Organizations
  Future<List<Organization>> listOrganizations() async {
    final resp = await dio.get('/auth/organization/list');
    final body = resp.data as Map<String, dynamic>;
    final orgs = body['organizations'] as List<dynamic>? ?? [];
    return orgs
        .map((o) => Organization.fromJson(o as Map<String, dynamic>))
        .toList();
  }

  // Projects
  Future<List<Project>> listProjects(String workspaceId) async {
    final resp =
        await dio.get('/project', queryParameters: {'workspaceId': workspaceId});
    final data = resp.data;
    final list = data is List ? data : (data['data'] as List<dynamic>? ?? []);
    return list
        .map((p) => Project.fromJson(p as Map<String, dynamic>))
        .toList();
  }

  Future<Project> createProject(
      String workspaceId, String name, String icon, String slug) async {
    final resp = await dio.post('/project', data: {
      'workspaceId': workspaceId,
      'name': name,
      'icon': icon,
      'slug': slug,
    });
    return Project.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<void> deleteProject(String id) async {
    await dio.delete('/project/$id');
  }

  // Board
  Future<Board> board(String projectId) async {
    final resp = await dio.get('/task/tasks/$projectId');
    return Board.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<BoardTask> createTask(
      String projectId, String title, String status) async {
    final resp = await dio.post('/task/$projectId', data: {
      'title': title,
      'status': status,
    });
    return BoardTask.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<void> setTaskStatus(String taskId, String status) async {
    await dio.put('/task/status/$taskId', data: {'status': status});
  }

  Future<void> setTaskPriority(String taskId, String priority) async {
    await dio.put('/task/priority/$taskId', data: {'priority': priority});
  }

  // GitHub Integration
  Future<Map<String, dynamic>?> githubAppInfo() async {
    final resp = await dio.get('/github-integration/app-info');
    if (resp.data == null || resp.data == 'null') return null;
    return resp.data as Map<String, dynamic>?;
  }
}
