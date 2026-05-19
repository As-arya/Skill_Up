import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'user_session.dart';
import 'profile_page.dart';

class HomePage extends StatefulWidget {
  final void Function(int tabIndex)? onNavigateToTab;

  const HomePage({super.key, this.onNavigateToTab});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isLoading = true;
  String? _error;

  String _userName = '';
  String? _targetRole;
  int _jobReadiness = 0;
  int _skillsToMaster = 0;
  List<Map<String, dynamic>> _groupedSkills = [];
  Map<String, dynamic>? _dailyGoal;
  String? _profileImagePath;

  @override
  void initState() {
    super.initState();
    _fetchDashboard();
    _loadProfileImage();
  }

  Future<void> _loadProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _profileImagePath = prefs.getString('profile_image_${UserSession.instance.userId}');
    });
  }

  Future<void> _fetchDashboard() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final session = UserSession.instance;
      final data = await ApiService.instance.getDashboard(session.userId, session.token);
      if (mounted) {
        setState(() {
          _userName = data['userName'] ?? 'User';
          _targetRole = data['targetRole'];
          _jobReadiness = data['jobReadiness'] ?? 0;
          _skillsToMaster = data['skillsToMaster'] ?? 0;
          _groupedSkills = List<Map<String, dynamic>>.from(data['groupedSkills'] as List? ?? []);
          _dailyGoal = data['dailyGoal'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() { _error = 'Cannot reach backend. Is the server running?'; _isLoading = false; });
      }
    }
  }

  // ─── Set Daily Goal Dialog ──────────────────────────────
  // Loads existing categories, lets user pick one.
  // Smart default: picks the category with the lowest completion %.
  void _showSetGoalDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _SetGoalDialog(
        onGoalSet: (categoryName) async {
          try {
            final session = UserSession.instance;
            await ApiService.instance.createLearningTarget(
              userId: session.userId,
              targetRole: categoryName,
              token: session.token,
              targetMinutes: 30, // kept for DB compat, not used in UI
            );
            await _fetchDashboard();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Daily goal set: $categoryName'),
                  backgroundColor: const Color(0xFF8A2BE2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Failed to set goal'), backgroundColor: Colors.redAccent),
              );
            }
          }
        },
      ),
    );
  }

  // ─── Toggle a sub-skill directly from the daily goal card ──
  Future<void> _toggleSubSkill(int skillId, bool currentValue) async {
    final session = UserSession.instance;
    final ok = await ApiService.instance.toggleSkill(skillId, !currentValue, session.token);
    if (ok && mounted) await _fetchDashboard();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;

    return SafeArea(
      child: _isLoading
          ? Center(child: CircularProgressIndicator(color: cs.primary))
          : _error != null
              ? _buildError(t, cs)
              : _buildContent(t, cs),
    );
  }

  Widget _buildError(ThemeData t, ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off, color: cs.onSurface.withValues(alpha: 0.38), size: 56),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurface.withValues(alpha: 0.54), fontSize: 14)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchDashboard,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(backgroundColor: cs.primary, foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ThemeData t, ColorScheme cs) {

    return RefreshIndicator(
      onRefresh: () async {
        await _fetchDashboard();
        await _loadProfileImage();
      },
      color: cs.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Header ─────────────────────────────────
            Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage())),
                  child: Container(
                    margin: const EdgeInsets.only(right: 16),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: cs.primary, width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 24,
                      backgroundColor: t.dividerColor,
                      backgroundImage: _profileImagePath != null && File(_profileImagePath!).existsSync()
                          ? FileImage(File(_profileImagePath!)) as ImageProvider
                          : const AssetImage('assets/placeholder-profile.png'),
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hi, ${_userName.split(' ')[0].replaceAll(RegExp(r'[^\w\s]'), '')}',
                        style: TextStyle(color: cs.onSurface, fontSize: 28, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text("Let's boost your career readiness",
                          style: TextStyle(color: cs.onSurface.withValues(alpha: 0.54), fontSize: 15)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ─── Job Readiness Card ─────────────────────
            _card(t, child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title: Target role
                Text(
                  'Target: ${_targetRole ?? 'Not Set'}',
                  style: TextStyle(color: cs.onSurface, fontSize: 22, fontWeight: FontWeight.bold),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                // Trending subtitle
                Row(children: [
                  Icon(Icons.trending_up, color: cs.primary, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'Trending positively',
                    style: TextStyle(color: cs.primary, fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ]),
                const SizedBox(height: 32),
                // Circular progress chart
                Center(
                  child: SizedBox(
                    height: 180, width: 180,
                    child: CustomPaint(
                      painter: _ReadinessRingPainter(
                        progress: _jobReadiness / 100.0,
                        progressColor: cs.primary,
                        backgroundColor: t.dividerColor.withValues(alpha: 0.4),
                        strokeWidth: 14,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$_jobReadiness%',
                              style: TextStyle(
                                color: cs.primary,
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Ready',
                              style: TextStyle(
                                color: cs.onSurface.withValues(alpha: 0.6),
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                // Skills Gap row
                GestureDetector(
                  onTap: () => widget.onNavigateToTab?.call(0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: t.scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFE0EC),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(Icons.psychology_outlined, color: Color(0xFFE91E63), size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Skills Gap', style: TextStyle(color: cs.onSurface, fontSize: 15, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text(
                                '$_skillsToMaster skills to master',
                                style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5), fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: cs.onSurface.withValues(alpha: 0.3), size: 24),
                      ],
                    ),
                  ),
                ),
              ],
            )),
            const SizedBox(height: 24),

            // ─── Grouped Skills Progress ─────────────────────────────
            Text('Skills by Category', style: TextStyle(color: cs.onSurface, fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            _card(t, child: _groupedSkills.isEmpty
                ? Center(child: Text('No skills yet', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.54))))
                : Column(children: [
                    for (int i = 0; i < _groupedSkills.length && i < 5; i++) ...[
                      if (i > 0) const SizedBox(height: 20),
                      _buildSkillBar(
                        _groupedSkills[i]['name'] ?? '', 
                        (_groupedSkills[i]['percentage'] ?? 0).toDouble() / 100.0,
                        _groupedSkills[i]['percentage'] ?? 0,
                        i
                      ),
                    ],
                  ]),
            ),
            const SizedBox(height: 32),

            // ─── Quick Actions ──────────────────────────
            Text('Quick Actions', style: TextStyle(color: cs.onSurface, fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            _buildQuickAction('Check CV', Icons.description_outlined, [const Color(0xFF13B5EA), const Color(0xFF2C6CFF)], () {
              widget.onNavigateToTab?.call(3);
            }),
            _buildQuickAction('Analyze Portfolio', Icons.work_outline, [const Color(0xFFFF2E93), const Color(0xFFFF8E53)], () {
              widget.onNavigateToTab?.call(4);
            }),
            _buildQuickAction('Skill Match', Icons.track_changes, [const Color(0xFF8A2BE2), const Color(0xFFB066FF)], () {
              widget.onNavigateToTab?.call(5);
            }),

            const SizedBox(height: 32),

            // ─── Daily Goal ─────────────────────────────
            _dailyGoal != null
              ? _buildDailyGoalCard(t, cs)
              : GestureDetector(
                  onTap: _showSetGoalDialog,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: t.dividerColor, width: 1.5),
                    ),
                    child: Row(children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFF8A2BE2).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.add, color: Color(0xFFB066FF), size: 22),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Set a Daily Goal', style: TextStyle(color: cs.onSurface, fontSize: 15, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text('Pick a skill category to focus on today', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5), fontSize: 13)),
                        ]),
                      ),
                      Icon(Icons.chevron_right, color: cs.onSurface.withValues(alpha: 0.3), size: 24),
                    ]),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  // ─── Reusable Card Container ────────────────────────────────────
  Widget _card(ThemeData t, {required Widget child}) {
    final isDark = t.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: t.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4))],
        border: isDark ? Border.all(color: t.dividerColor, width: 0.5) : null,
      ),
      child: child,
    );
  }

  static const List<List<Color>> _skillGradients = [
    [Color(0xFF13B5EA), Color(0xFF2C6CFF)],
    [Color(0xFFFF2E93), Color(0xFFFF8E53)],
    [Color(0xFF8A2BE2), Color(0xFFB066FF)],
    [Color(0xFF00C896), Color(0xFF00A67E)],
    [Color(0xFFFFB300), Color(0xFFFF8F00)],
  ];

  Widget _buildSkillBar(String label, double value, int percentage, int index) {
    final t = Theme.of(context);
    final cs = t.colorScheme;
    final gradient = _skillGradients[index % _skillGradients.length];

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7), fontSize: 13)),
        Text('$percentage%', style: TextStyle(color: gradient.first, fontSize: 13, fontWeight: FontWeight.bold)),
      ]),
      const SizedBox(height: 8),
      Container(
        height: 6,
        decoration: BoxDecoration(color: t.dividerColor, borderRadius: BorderRadius.circular(3)),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft, widthFactor: value,
          child: Container(
            decoration: BoxDecoration(gradient: LinearGradient(colors: gradient), borderRadius: BorderRadius.circular(3)),
          ),
        ),
      ),
    ]);
  }

  Widget _buildQuickAction(String title, IconData icon, List<Color> gradient, VoidCallback onTap) {
    final t = Theme.of(context);
    final cs = t.colorScheme;
    final isDark = t.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4))],
          border: isDark ? Border.all(color: t.dividerColor, width: 0.5) : null,
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(gradient: LinearGradient(colors: gradient), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Text(title, style: TextStyle(color: cs.onSurface, fontSize: 16, fontWeight: FontWeight.w600)),
          const Spacer(),
          Icon(Icons.chevron_right, color: cs.onSurface.withValues(alpha: 0.38), size: 20),
        ]),
      ),
    );
  }

  // ─── Daily Goal Card ────────────────────────────────────────────
  Widget _buildDailyGoalCard(ThemeData t, ColorScheme cs) {
    final goal = _dailyGoal!;
    final categoryName = goal['categoryName'] as String? ?? '';
    final mastered     = (goal['mastered'] as num?)?.toInt() ?? 0;
    final total        = (goal['totalSubSkills'] as num?)?.toInt() ?? 0;
    final progress     = (goal['progressPercent'] as num?)?.toDouble() ?? 0.0;
    final subSkills    = List<Map<String, dynamic>>.from(goal['subSkills'] as List? ?? []);
    final isDark       = t.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: t.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF8A2BE2).withValues(alpha: 0.3), width: 1),
        boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header ──
        Row(children: [
          const Icon(Icons.star_outline, color: Color(0xFFB066FF), size: 20),
          const SizedBox(width: 8),
          Text('Daily Goal', style: TextStyle(color: cs.onSurface, fontSize: 16, fontWeight: FontWeight.w600)),
          const Spacer(),
          GestureDetector(
            onTap: _showSetGoalDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF8A2BE2).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('Change', style: TextStyle(color: Color(0xFFB066FF), fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
        const SizedBox(height: 4),
        Text(
          categoryName,
          style: TextStyle(color: cs.onSurface, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),

        // ── Progress bar ──
        Row(children: [
          Expanded(
            child: Container(
              height: 6,
              decoration: BoxDecoration(color: t.dividerColor, borderRadius: BorderRadius.circular(3)),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF8A2BE2), Color(0xFFB066FF)]),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$mastered / $total',
            style: TextStyle(color: const Color(0xFFB066FF), fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ]),
        const SizedBox(height: 4),
        Text(
          '$mastered of $total sub-skills mastered',
          style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5), fontSize: 12),
        ),
        const SizedBox(height: 16),

        // ── Sub-skill checklist (up to 3) ──
        ...subSkills.map((s) {
          final isChecked = s['isChecked'] as bool? ?? false;
          final skillId   = (s['id'] as num).toInt();
          return GestureDetector(
            onTap: () => _toggleSubSkill(skillId, isChecked),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isChecked
                    ? const Color(0xFF8A2BE2).withValues(alpha: 0.08)
                    : t.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isChecked
                      ? const Color(0xFF8A2BE2).withValues(alpha: 0.4)
                      : t.dividerColor,
                ),
              ),
              child: Row(children: [
                Icon(
                  isChecked ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: isChecked ? const Color(0xFF8A2BE2) : cs.onSurface.withValues(alpha: 0.3),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    s['name'] as String? ?? '',
                    style: TextStyle(
                      color: isChecked ? const Color(0xFF8A2BE2) : cs.onSurface,
                      fontSize: 14,
                      fontWeight: isChecked ? FontWeight.w500 : FontWeight.normal,
                      decoration: isChecked ? TextDecoration.lineThrough : null,
                      decorationColor: const Color(0xFF8A2BE2).withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ]),
            ),
          );
        }),

        // ── "See all" hint if category has more than 3 skills ──
        if (total > 3) ...[
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => widget.onNavigateToTab?.call(0),
            child: Text(
              '+ ${total - subSkills.length} more in Skills tab',
              style: const TextStyle(color: Color(0xFFB066FF), fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ]),
    );
  }

}

// ─── Custom Circular Ring Painter ─────────────────────────────────
class _ReadinessRingPainter extends CustomPainter {
  final double progress;
  final Color progressColor;
  final Color backgroundColor;
  final double strokeWidth;

  _ReadinessRingPainter({
    required this.progress,
    required this.progressColor,
    required this.backgroundColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Draw background ring
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    // Draw progress arc
    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    const startAngle = -90.0 * 3.14159265 / 180.0; // Start from top
    final sweepAngle = progress * 2 * 3.14159265;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ReadinessRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

// ─── Set Goal Dialog ───────────────────────────────────────────────
// Loads categories from the backend, shows them as selectable cards.
// Smart default: pre-selects the category with the lowest completion %.
class _SetGoalDialog extends StatefulWidget {
  final void Function(String categoryName) onGoalSet;
  const _SetGoalDialog({required this.onGoalSet});

  @override
  State<_SetGoalDialog> createState() => _SetGoalDialogState();
}

class _SetGoalDialogState extends State<_SetGoalDialog> {
  bool _loading = true;
  List<Map<String, dynamic>> _categories = [];
  String? _selected;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final session = UserSession.instance;
      final cats = await ApiService.instance.getDashboardCategories(session.userId, session.token);
      if (mounted) {
        setState(() {
          _categories = cats;
          // Smart default: category with lowest completion % (most to learn)
          if (cats.isNotEmpty) {
            final sorted = List<Map<String, dynamic>>.from(cats)
              ..sort((a, b) => (a['percentage'] as int).compareTo(b['percentage'] as int));
            _selected = sorted.first['name'] as String;
          }
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return AlertDialog(
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(children: [
        const Icon(Icons.star_outline, color: Color(0xFFB066FF), size: 22),
        const SizedBox(width: 8),
        Text('Set Daily Goal', style: TextStyle(color: cs.onSurface, fontSize: 18)),
      ]),
      content: SizedBox(
        width: double.maxFinite,
        child: _loading
            ? const SizedBox(
                height: 80,
                child: Center(child: CircularProgressIndicator(color: Color(0xFF8A2BE2))),
              )
            : _categories.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'No skill categories found.\nAdd skills with categories in the Skills tab first.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6), fontSize: 14, height: 1.5),
                    ),
                  )
                : SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Pick a category to focus on today',
                          style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6), fontSize: 13),
                        ),
                        const SizedBox(height: 16),
                        ..._categories.map((cat) {
                          final name       = cat['name'] as String;
                          final pct        = cat['percentage'] as int;
                          final total      = cat['total'] as int;
                          final mastered   = cat['mastered'] as int;
                          final isSelected = _selected == name;

                          return GestureDetector(
                            onTap: () => setState(() => _selected = name),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF8A2BE2).withValues(alpha: 0.12)
                                    : theme.scaffoldBackgroundColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF8A2BE2)
                                      : theme.dividerColor,
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Row(children: [
                                Icon(
                                  isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                  color: isSelected ? const Color(0xFF8A2BE2) : cs.onSurface.withValues(alpha: 0.3),
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(name, style: TextStyle(
                                      color: cs.onSurface,
                                      fontSize: 14,
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                    )),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$mastered / $total mastered',
                                      style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5), fontSize: 12),
                                    ),
                                  ]),
                                ),
                                const SizedBox(width: 8),
                                // Mini progress bar
                                SizedBox(
                                  width: 48,
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                    Text('$pct%', style: TextStyle(
                                      color: isSelected ? const Color(0xFF8A2BE2) : cs.onSurface.withValues(alpha: 0.5),
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    )),
                                    const SizedBox(height: 4),
                                    Container(
                                      height: 4,
                                      decoration: BoxDecoration(color: theme.dividerColor, borderRadius: BorderRadius.circular(2)),
                                      child: FractionallySizedBox(
                                        alignment: Alignment.centerLeft,
                                        widthFactor: pct / 100.0,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: isSelected ? const Color(0xFF8A2BE2) : const Color(0xFF13B5EA),
                                            borderRadius: BorderRadius.circular(2),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ]),
                                ),
                              ]),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.54))),
        ),
        if (_selected != null)
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8A2BE2),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(context);
              widget.onGoalSet(_selected!);
            },
            child: const Text('Set Goal'),
          ),
      ],
    );
  }
}