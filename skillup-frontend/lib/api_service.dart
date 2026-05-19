import 'dart:convert';
import 'package:http/http.dart' as http;

/// Central API service for all backend calls.
class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  // Base URL is injected at build time via --dart-define=API_BASE_URL=...
  // Defaults to Android emulator localhost for local development.
  // For production build: flutter run --dart-define=API_BASE_URL=https://skillup-backend.onrender.com/api
  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://skillup-production-f207.up.railway.app/api',
  );

  Map<String, String> _headers(String? token) => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  /// Helper to handle non-200 responses and throw meaningful errors.
  Map<String, dynamic> _handleResponse(http.Response res) {
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return body;
    }
    final errorMsg = body['error'] ?? 'Request failed with status ${res.statusCode}';
    throw Exception(errorMsg);
  }

  // ─── Auth ───────────────────────────────────────────────────

  /// POST /api/login
  Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await http
        .post(
          Uri.parse('$_baseUrl/login'),
          headers: _headers(null),
          body: jsonEncode({'email': email, 'password': password}),
        )
        .timeout(const Duration(seconds: 10));
    // Auth uses its own error handling (returns error key in body)
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// POST /api/register
  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String university,
    required String password,
  }) async {
    final res = await http
        .post(
          Uri.parse('$_baseUrl/register'),
          headers: _headers(null),
          body: jsonEncode({
            'name': name,
            'email': email,
            'university': university,
            'password': password,
          }),
        )
        .timeout(const Duration(seconds: 10));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ─── Dashboard ───────────────────────────────────────────────

  /// GET /api/dashboard?userId=X
  Future<Map<String, dynamic>> getDashboard(int userId, String token) async {
    final res = await http
        .get(
          Uri.parse('$_baseUrl/dashboard?userId=$userId'),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 10));
    return _handleResponse(res);
  }

  /// GET /api/dashboard/categories?userId=X
  /// Returns all skill categories with completion stats for the goal picker.
  Future<List<Map<String, dynamic>>> getDashboardCategories(int userId, String token) async {
    final res = await http
        .get(
          Uri.parse('$_baseUrl/dashboard/categories?userId=$userId'),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 10));
    final body = _handleResponse(res);
    return List<Map<String, dynamic>>.from(body['categories'] as List? ?? []);
  }

  // ─── Skills ──────────────────────────────────────────────────

  /// GET /api/skills?userId=X
  Future<Map<String, dynamic>> getSkills(int userId, String token) async {
    final res = await http
        .get(
          Uri.parse('$_baseUrl/skills?userId=$userId'),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 10));
    return _handleResponse(res);
  }

  /// POST /api/skills — create new skill
  Future<Map<String, dynamic>> createSkill({
    required int userId,
    required String name,
    required bool isChecked,
    required String token,
  }) async {
    final res = await http
        .post(
          Uri.parse('$_baseUrl/skills'),
          headers: _headers(token),
          body: jsonEncode({
            'userId': userId,
            'name': name,
            'isChecked': isChecked,
          }),
        )
        .timeout(const Duration(seconds: 10));
    return _handleResponse(res);
  }

  /// POST /api/skills — create new skill with category
  Future<Map<String, dynamic>> createSkillWithCategory({
    required int userId,
    required String name,
    required String category,
    required bool isChecked,
    required String token,
  }) async {
    final res = await http
        .post(
          Uri.parse('$_baseUrl/skills'),
          headers: _headers(token),
          body: jsonEncode({
            'userId': userId,
            'name': name,
            'category': category,
            'isChecked': isChecked,
          }),
        )
        .timeout(const Duration(seconds: 10));
    return _handleResponse(res);
  }

  /// PUT /api/skills/[id]  — toggle isChecked
  Future<bool> toggleSkill(int skillId, bool isChecked, String token) async {
    final res = await http
        .put(
          Uri.parse('$_baseUrl/skills/$skillId'),
          headers: _headers(token),
          body: jsonEncode({'isChecked': isChecked}),
        )
        .timeout(const Duration(seconds: 10));
    return res.statusCode == 200;
  }

  /// DELETE /api/skills/[id] — delete a skill
  Future<bool> deleteSkill(int skillId, String token) async {
    final res = await http
        .delete(
          Uri.parse('$_baseUrl/skills/$skillId'),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 10));
    return res.statusCode == 200;
  }

  /// PUT /api/skills/[id] — rename a skill
  Future<bool> renameSkill(int skillId, String newName, String token) async {
    final res = await http
        .put(
          Uri.parse('$_baseUrl/skills/$skillId'),
          headers: _headers(token),
          body: jsonEncode({'name': newName}),
        )
        .timeout(const Duration(seconds: 10));
    return res.statusCode == 200;
  }

  /// POST /api/skills/confirm-mastery
  Future<Map<String, dynamic>> confirmMastery({
    required int userId,
    required List<String> skillNames,
    required String token,
  }) async {
    final res = await http
        .post(
          Uri.parse('$_baseUrl/skills/confirm-mastery'),
          headers: _headers(token),
          body: jsonEncode({
            'userId': userId,
            'skillNames': skillNames,
          }),
        )
        .timeout(const Duration(seconds: 10));
    return _handleResponse(res);
  }

  /// POST /api/skills/cleanup — remove corrupted skill entries
  Future<Map<String, dynamic>> cleanupSkills({
    required int userId,
    required String token,
  }) async {
    final res = await http
        .post(
          Uri.parse('$_baseUrl/skills/cleanup'),
          headers: _headers(token),
          body: jsonEncode({'userId': userId}),
        )
        .timeout(const Duration(seconds: 10));
    return _handleResponse(res);
  }

  // ─── Projects ────────────────────────────────────────────────

  /// GET /api/projects?userId=X
  Future<Map<String, dynamic>> getProjects(int userId, String token) async {
    final res = await http
        .get(
          Uri.parse('$_baseUrl/projects?userId=$userId'),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 10));
    return _handleResponse(res);
  }

  /// POST /api/projects — create new project
  Future<Map<String, dynamic>> createProject({
    required int userId,
    required String title,
    required String description,
    required List<String> tags,
    required List<Map<String, String>> links,
    required String token,
  }) async {
    final res = await http
        .post(
          Uri.parse('$_baseUrl/projects'),
          headers: _headers(token),
          body: jsonEncode({
            'userId': userId,
            'title': title,
            'description': description,
            'tags': tags,
            'links': links,
          }),
        )
        .timeout(const Duration(seconds: 10));
    return _handleResponse(res);
  }

  /// PUT /api/projects/:id — update existing project
  Future<Map<String, dynamic>> updateProject({
    required int id,
    required String title,
    required String description,
    required List<String> tags,
    required List<Map<String, String>> links,
    required String token,
  }) async {
    final res = await http
        .put(
          Uri.parse('$_baseUrl/projects/$id'),
          headers: _headers(token),
          body: jsonEncode({
            'title': title,
            'description': description,
            'tags': tags,
            'links': links,
          }),
        )
        .timeout(const Duration(seconds: 10));
    return _handleResponse(res);
  }

  /// DELETE /api/projects/:id — delete a project
  Future<Map<String, dynamic>> deleteProject({
    required int id,
    required String token,
  }) async {
    final res = await http
        .delete(
          Uri.parse('$_baseUrl/projects/$id'),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 10));
    return _handleResponse(res);
  }

  /// GET /api/projects/fetch-readme
  Future<Map<String, dynamic>> fetchReadme({
    required String repoUrl,
    required String token,
  }) async {
    final encodedUrl = Uri.encodeComponent(repoUrl);
    final res = await http
        .get(
          Uri.parse('$_baseUrl/projects/fetch-readme?repoUrl=$encodedUrl'),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 10));
    return _handleResponse(res);
  }

  // ─── Learning Targets ────────────────────────────────────────

  /// POST /api/learning-targets
  Future<Map<String, dynamic>> createLearningTarget({
    required int userId,
    required String targetRole,
    required String token,
    int targetMinutes = 30,
  }) async {
    final res = await http
        .post(
          Uri.parse('$_baseUrl/learning-targets'),
          headers: _headers(token),
          body: jsonEncode({
            'userId': userId,
            'skillName': targetRole,
            'targetMinutes': targetMinutes,
          }),
        )
        .timeout(const Duration(seconds: 10));
    return _handleResponse(res);
  }

  // ─── AI Analysis ──────────────────────────────────────────────

  /// POST /api/validate-cv — check if uploaded file is actually a CV
  Future<Map<String, dynamic>> validateCV({
    required int userId,
    String? cvContent,
    String? imageBase64,
    String? mimeType,
    required String token,
  }) async {
    final res = await http
        .post(
          Uri.parse('$_baseUrl/validate-cv'),
          headers: _headers(token),
          body: jsonEncode({
            'userId': userId,
            'cvText': cvContent,
            'cvImage': imageBase64,
            'mimeType': mimeType,
          }),
        )
        .timeout(const Duration(seconds: 45));
    return _handleResponse(res);
  }

  /// GET /api/job-suggestions — get list of known job titles for autocomplete
  Future<List<String>> getJobSuggestions(String token) async {
    final res = await http
        .get(
          Uri.parse('$_baseUrl/job-suggestions'),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 10));
    final body = _handleResponse(res);
    final jobs = body['jobs'] as List?;
    return jobs?.map((e) => e.toString()).toList() ?? [];
  }

  /// POST /api/validate-job — validate and autocorrect job title
  Future<Map<String, dynamic>> validateJob({
    required String jobTitle,
    required String token,
  }) async {
    final res = await http
        .post(
          Uri.parse('$_baseUrl/validate-job'),
          headers: _headers(token),
          body: jsonEncode({'jobTitle': jobTitle}),
        )
        .timeout(const Duration(seconds: 30));
    return _handleResponse(res);
  }

  /// POST /api/extract-cv
  Future<Map<String, dynamic>> extractCV({
    required int userId,
    String? cvContent,
    String? imageBase64,
    String? mimeType,
    required String token,
  }) async {
    final res = await http
        .post(
          Uri.parse('$_baseUrl/extract-cv'),
          headers: _headers(token),
          body: jsonEncode({
            'userId': userId,
            'cvText': cvContent,
            'cvImage': imageBase64,
            'mimeType': mimeType,
          }),
        )
        .timeout(const Duration(seconds: 30));
    return _handleResponse(res);
  }

  /// POST /api/cv-check
  Future<Map<String, dynamic>> analyzeCV({
    required int userId,
    String? cvContent,
    String? imageBase64,
    String? mimeType,
    required String token,
  }) async {
    final res = await http
        .post(
          Uri.parse('$_baseUrl/cv-check'),
          headers: _headers(token),
          body: jsonEncode({
            'userId': userId,
            'cvText': cvContent,
            'cvImage': imageBase64,
            'mimeType': mimeType,
          }),
        )
        .timeout(const Duration(seconds: 40));
    return _handleResponse(res);
  }

  /// POST /api/match (Skill Matching)
  Future<Map<String, dynamic>> analyzeMatch({
    required int userId,
    required String roleDescription,
    String? cvContent,
    String? imageBase64,
    String? mimeType,
    required String token,
  }) async {
    final res = await http
        .post(
          Uri.parse('$_baseUrl/match'),
          headers: _headers(token),
          body: jsonEncode({
            'userId': userId,
            'roleDescription': roleDescription,
            'cvContent': cvContent,
            'cvImage': imageBase64,
            'mimeType': mimeType,
          }),
        )
        .timeout(const Duration(seconds: 30));
    return _handleResponse(res);
  }

  /// POST /api/portfolio (Portfolio Checking)
  Future<Map<String, dynamic>> analyzePortfolio({
    required int userId,
    required String jobTitle,
    String? content,
    String? imageBase64,
    String? mimeType,
    required String token,
  }) async {
    final res = await http
        .post(
          Uri.parse('$_baseUrl/portfolio'),
          headers: _headers(token),
          body: jsonEncode({
            'userId': userId,
            'jobTitle': jobTitle,
            'content': content,
            'portfolioImage': imageBase64,
            'mimeType': mimeType,
          }),
        )
        .timeout(const Duration(seconds: 30));
    return _handleResponse(res);
  }

  /// POST /api/portfolio/scrape (Portfolio Scraping)
  Future<Map<String, dynamic>> scrapePortfolio({
    required int userId,
    required String jobTitle,
    required String url,
    required String token,
  }) async {
    final res = await http
        .post(
          Uri.parse('$_baseUrl/portfolio/scrape'),
          headers: _headers(token),
          body: jsonEncode({
            'userId': userId,
            'jobTitle': jobTitle,
            'url': url,
          }),
        )
        .timeout(const Duration(seconds: 60)); // Higher timeout for scraping
    return _handleResponse(res);
  }
}
