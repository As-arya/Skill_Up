import 'package:flutter/material.dart';
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
  int _jobReadiness = 0;
  int _skillGap = 0;
  int _skillsToMaster = 0;
  List<Map<String, dynamic>> _topSkills = [];
  Map<String, dynamic>? _dailyGoal;

  @override
  void initState() {
    super.initState();
    _fetchDashboard();
  }

  Future<void> _fetchDashboard() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final session = UserSession.instance;
      final data = await ApiService.instance.getDashboard(session.userId, session.token);
      if (mounted) {
        setState(() {
          _userName = data['userName'] ?? 'User';
          _jobReadiness = data['jobReadiness'] ?? 0;
          _skillGap = data['skillGap'] ?? 0;
          _skillsToMaster = data['skillsToMaster'] ?? 0;
          _topSkills = List<Map<String, dynamic>>.from(data['topSkills'] as List? ?? []);
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
      onRefresh: _fetchDashboard,
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
                      backgroundImage: const NetworkImage('https://i.pravatar.cc/300?img=11'),
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
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Job Readiness', style: TextStyle(color: cs.onSurface, fontSize: 18, fontWeight: FontWeight.w600)),
                    Row(children: [
                      GestureDetector(
                        onTap: _showSetTargetJobDialog,
                        child: Icon(Icons.edit, color: cs.onSurface.withValues(alpha: 0.54), size: 20),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.trending_up, color: cs.primary, size: 20),
                      const SizedBox(width: 4),
                      Text('$_jobReadiness%', style: TextStyle(color: cs.primary, fontSize: 20, fontWeight: FontWeight.bold)),
                    ]),
                  ],
                ),
                const SizedBox(height: 32),
                SizedBox(
                  height: 120, width: 120,
                  child: Stack(fit: StackFit.expand, children: [
                    CircularProgressIndicator(
                      value: _jobReadiness / 100.0,
                      strokeWidth: 10,
                      backgroundColor: t.dividerColor,
                      valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                    ),
                    Center(child: Icon(Icons.bolt, color: cs.primary, size: 48)),
                  ]),
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: t.scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Skills Gap', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7), fontSize: 13)),
                        const SizedBox(height: 4),
                        Text('$_skillsToMaster skills to master for your target role',
                            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.38), fontSize: 11)),
                      ]),
                      Text('$_skillGap%', style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            )),
            const SizedBox(height: 24),

            // ─── Top Skills ─────────────────────────────
            Text('Top Skills', style: TextStyle(color: cs.onSurface, fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            _card(t, child: _topSkills.isEmpty
                ? Center(child: Text('No skills yet', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.54))))
                : Column(children: [
                    for (int i = 0; i < _topSkills.length && i < 5; i++) ...[
                      if (i > 0) const SizedBox(height: 20),
                      _buildSkillBar(_topSkills[i]['name'] ?? '', _topSkills[i]['mastered'] == true, i),
                    ],
                  ]),
            ),
            const SizedBox(height: 32),

            // ─── Quick Actions ──────────────────────────
            Text('Quick Actions', style: TextStyle(color: cs.onSurface, fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            _buildQuickAction('Check CV', Icons.description_outlined, [const Color(0xFF13B5EA), const Color(0xFF2C6CFF)], () => widget.onNavigateToTab?.call(3)),
            _buildQuickAction('Analyze Portfolio', Icons.work_outline, [const Color(0xFFFF2E93), const Color(0xFFFF8E53)], () => widget.onNavigateToTab?.call(2)),
            _buildQuickAction('Skill Match', Icons.track_changes, [const Color(0xFF8A2BE2), const Color(0xFFB066FF)], () => widget.onNavigateToTab?.call(4)),

            const SizedBox(height: 32),

            // ─── Daily Goal ─────────────────────────────
            if (_dailyGoal != null)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: t.scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: cs.primary.withValues(alpha: 0.3), width: 1),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.star_outline, color: Color(0xFFB066FF), size: 20),
                    const SizedBox(width: 8),
                    Text('Daily Goal', style: TextStyle(color: cs.onSurface, fontSize: 16, fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 8),
                  Text('Study ${_dailyGoal!['skillName']} for ${_dailyGoal!['targetMinutes']} minutes today',
                      style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7), fontSize: 13, height: 1.4)),
                  const SizedBox(height: 20),
                  Row(children: [
                    Expanded(
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(color: t.dividerColor, borderRadius: BorderRadius.circular(3)),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: (_dailyGoal!['progressPercent'] ?? 0.0).toDouble(),
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
                    Text(_dailyGoal!['progress'] ?? '',
                        style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7), fontSize: 13, fontWeight: FontWeight.bold)),
                  ]),
                ]),
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

  Widget _buildSkillBar(String label, bool mastered, int index) {
    final t = Theme.of(context);
    final cs = t.colorScheme;
    final gradient = _skillGradients[index % _skillGradients.length];
    final value = mastered ? 1.0 : 0.45;
    final pct = mastered ? '100%' : '~45%';

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7), fontSize: 13)),
        Text(pct, style: TextStyle(color: gradient.first, fontSize: 13, fontWeight: FontWeight.bold)),
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

  void _showSetTargetJobDialog() {
    String selectedRole = 'Frontend Developer';
    final roles = ['Frontend Developer', 'Backend Developer', 'Full Stack Engineer', 'Mobile Developer', 'UI/UX Designer', 'Data Scientist'];
    final t = Theme.of(context);
    final cs = t.colorScheme;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: cs.surface,
          title: Text('Set Target Job', style: TextStyle(color: cs.onSurface)),
          content: DropdownButtonFormField<String>(
            value: selectedRole,
            dropdownColor: cs.surface,
            style: TextStyle(color: cs.onSurface),
            decoration: InputDecoration(
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: cs.primary.withValues(alpha: 0.5))),
              focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: cs.primary)),
            ),
            items: roles.map((role) => DropdownMenuItem(value: role, child: Text(role))).toList(),
            onChanged: (val) { if (val != null) setState(() => selectedRole = val); },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.54)))),
            ElevatedButton(
              onPressed: () async { Navigator.pop(context); await _saveTargetJob(selectedRole); },
              style: ElevatedButton.styleFrom(backgroundColor: cs.primary, foregroundColor: Colors.white),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveTargetJob(String role) async {
    setState(() => _isLoading = true);
    try {
      final session = UserSession.instance;
      await ApiService.instance.createLearningTarget(userId: session.userId, targetRole: role, token: session.token);
      await _fetchDashboard();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save target job: $e')));
      }
    }
  }
}