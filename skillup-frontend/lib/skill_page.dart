import 'package:flutter/material.dart';
import 'api_service.dart';
import 'user_session.dart';

class SkillPage extends StatefulWidget {
  const SkillPage({super.key});
  @override
  State<SkillPage> createState() => _SkillPageState();
}

class _SkillPageState extends State<SkillPage> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _grouped = [];
  List<Map<String, dynamic>> _masteredGroups = [];
  int _mastered = 0, _total = 0, _overallPercentage = 0;

  @override
  void initState() { super.initState(); _fetchSkills(); }

  Future<void> _fetchSkills() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final s = UserSession.instance;
      // Auto-cleanup corrupted skills (from old Map.toString() bug)
      try { await ApiService.instance.cleanupSkills(userId: s.userId, token: s.token); } catch (_) {}
      final data = await ApiService.instance.getSkills(s.userId, s.token);
      if (mounted) {
        setState(() {
          _grouped = List<Map<String, dynamic>>.from(data['grouped'] as List? ?? []);
          _masteredGroups = List<Map<String, dynamic>>.from(data['masteredGroups'] as List? ?? []);
          _overallPercentage = data['overallPercentage'] as int? ?? 0;
          _total = data['totalSkills'] as int? ?? 0;
          _mastered = data['totalMastered'] as int? ?? 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = 'Cannot reach server.'; _isLoading = false; });
    }
  }

  Future<void> _toggleSkill(Map<String, dynamic> skill) async {
    final nv = !(skill['isChecked'] as bool);
    final ok = await ApiService.instance.toggleSkill(skill['id'], nv, UserSession.instance.token);
    if (ok && mounted) {
      // Re-fetch to update groups correctly
      await _fetchSkills();
    }
  }

  bool _isCoreSkill(Map<String, dynamic> skill) => skill['isChecked'] == true;

  // ─── FAB Actions ─────────────────────────────────────────

  void _showAddDialog({String? prefilledCategory}) {
    final nameCtrl = TextEditingController();
    final categoryCtrl = TextEditingController(text: prefilledCategory);
    
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(children: [
        Icon(Icons.add_circle, color: Color(0xFF13B5EA), size: 22),
        SizedBox(width: 8),
        Text('Add Skill', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18)),
      ]),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameCtrl, autofocus: true,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: 'Skill Name (e.g., Docker)',
              hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38)),
              filled: true, fillColor: Theme.of(context).scaffoldBackgroundColor,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          SizedBox(height: 12),
          TextField(
            controller: categoryCtrl,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: 'Category (Optional)',
              hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38)),
              filled: true, fillColor: Theme.of(context).scaffoldBackgroundColor,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54)))),
        ElevatedButton(
          onPressed: () async {
            final name = nameCtrl.text.trim();
            final category = categoryCtrl.text.trim();
            if (name.isEmpty) return;
            Navigator.pop(ctx);
            try {
              final ses = UserSession.instance;
              if (category.isNotEmpty) {
                await ApiService.instance.createSkillWithCategory(
                  userId: ses.userId, name: name, category: category, isChecked: false, token: ses.token
                );
              } else {
                await ApiService.instance.createSkill(
                  userId: ses.userId, name: name, isChecked: false, token: ses.token
                );
              }
              await _fetchSkills();
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('"$name" added!'), backgroundColor: Colors.green));
            } catch (e) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent));
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF13B5EA), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: Text('Add', style: TextStyle(color: Colors.white)),
        ),
      ],
    ));
  }

  void _showDeleteDialog(Map<String, dynamic> skill) {
    final isCore = _isCoreSkill(skill);
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(children: [
        Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 22),
        SizedBox(width: 8),
        Text('Delete Skill', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18)),
      ]),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Remove "${skill['name']}" from your checklist?', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7))),
        if (isCore) ...[
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.orangeAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.3))),
            child: Row(children: [
              Icon(Icons.info_outline, color: Colors.orangeAccent, size: 18),
              SizedBox(width: 8),
              Expanded(child: Text('This is a core skill extracted from your CV.', style: TextStyle(color: Colors.orangeAccent, fontSize: 12))),
            ]),
          ),
        ],
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54)))),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(ctx);
            final ok = await ApiService.instance.deleteSkill(skill['id'], UserSession.instance.token);
            if (ok && mounted) {
              await _fetchSkills();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted.'), backgroundColor: Colors.green));
              }
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: Text('Delete', style: TextStyle(color: Colors.white)),
        ),
      ],
    ));
  }

  void _showRenameDialog(Map<String, dynamic> skill) {
    final ctrl = TextEditingController(text: skill['name']);
    final isCore = _isCoreSkill(skill);
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(children: [
        Icon(Icons.edit, color: Color(0xFF13B5EA), size: 22),
        SizedBox(width: 8),
        Text('Rename Skill', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18)),
      ]),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        if (isCore) ...[
          Container(
            padding: EdgeInsets.all(12), margin: EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: Colors.orangeAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.3))),
            child: Row(children: [
              Icon(Icons.info_outline, color: Colors.orangeAccent, size: 18),
              SizedBox(width: 8),
              Expanded(child: Text('This is a core skill from your CV.', style: TextStyle(color: Colors.orangeAccent, fontSize: 12))),
            ]),
          ),
        ],
        TextField(
          controller: ctrl, autofocus: true,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          decoration: InputDecoration(
            filled: true, fillColor: Theme.of(context).scaffoldBackgroundColor,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54)))),
        ElevatedButton(
          onPressed: () async {
            final newName = ctrl.text.trim();
            if (newName.isEmpty || newName == skill['name']) { Navigator.pop(ctx); return; }
            Navigator.pop(ctx);
            final ok = await ApiService.instance.renameSkill(skill['id'], newName, UserSession.instance.token);
            if (ok && mounted) {
              await _fetchSkills();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Renamed to "$newName"'), backgroundColor: Colors.green));
              }
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF13B5EA), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: Text('Save', style: TextStyle(color: Colors.white)),
        ),
      ],
    ));
  }

  void _showSkillActionSheet(Map<String, dynamic> skill) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(child: Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.dividerColor, borderRadius: BorderRadius.circular(2))),
          SizedBox(height: 16),
          Text('"${skill['name']}"', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 16)),
          SizedBox(height: 16),
          ListTile(leading: Icon(Icons.edit, color: Color(0xFF13B5EA)), title: Text('Rename', style: TextStyle(color: theme.colorScheme.onSurface)), onTap: () { Navigator.pop(ctx); _showRenameDialog(skill); }),
          ListTile(leading: Icon(Icons.delete_outline, color: Colors.redAccent), title: Text('Delete', style: TextStyle(color: Colors.redAccent)), onTap: () { Navigator.pop(ctx); _showDeleteDialog(skill); }),
        ]),
      )),
    );
  }

  // ─── BUILD ───────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final progressPercent = _overallPercentage / 100.0;
    final unmastered = _total - _mastered;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: _isLoading || _error != null ? null : Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(colors: [Color(0xFF13B5EA), Color(0xFF2C6CFF)]),
          boxShadow: [BoxShadow(color: Color(0xFF13B5EA).withValues(alpha: 0.4), blurRadius: 12, offset: Offset(0, 4))],
        ),
        child: FloatingActionButton(
          onPressed: () => _showAddDialog(),
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Icon(Icons.add, color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: Color(0xFF13B5EA)))
            : _error != null ? _buildError()
            : RefreshIndicator(
                onRefresh: _fetchSkills, color: Color(0xFF13B5EA),
                child: SingleChildScrollView(
                  physics: AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(24, 24, 24, 80),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Skill Checklist', style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 28, fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text('Track your mastered skills', style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.54), fontSize: 15)),
                    SizedBox(height: 24),
                    // Progress Card
                    _buildProgressCard(theme, isDark, progressPercent, unmastered),
                    SizedBox(height: 24),
                    // Skills Groups
                    _buildSkillGroups(theme, isDark),
                  ]),
                ),
              ),
      ),
    );
  }

  Widget _buildProgressCard(ThemeData theme, bool isDark, double pct, int unmastered) {
    // Collect all mastered skill names from masteredGroups (100% groups)
    final Set<String> masteredNames = {};
    
    // 1. For fully mastered groups, add the Category name (except for 'General')
    for (final g in _masteredGroups) {
      final groupName = g['group'] as String? ?? 'General';
      if (groupName.toLowerCase() == 'general') {
        final skills = g['skills'] as List? ?? [];
        for (final s in skills) {
          if (s is Map && s['name'] != null) masteredNames.add(s['name'].toString());
        }
      } else {
        masteredNames.add(groupName);
      }
    }
    
    // 2. We deliberately DO NOT add individual checked skills from partially mastered groups (_grouped) 
    // to keep the Mastered section clean and uncrowded, as requested by the user.

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: BorderRadius.circular(20), boxShadow: isDark ? [] : [BoxShadow(color: Colors.black12, blurRadius: 10)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Overall Progress', style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w600)),
          Row(children: [
            Icon(Icons.trending_up, color: Color(0xFF13B5EA), size: 20),
            SizedBox(width: 4),
            Text('${(pct * 100).round()}%', style: TextStyle(color: Color(0xFF13B5EA).withValues(alpha: 0.9), fontSize: 18, fontWeight: FontWeight.bold)),
          ]),
        ]),
        SizedBox(height: 20),
        Container(height: 8, decoration: BoxDecoration(color: theme.dividerColor, borderRadius: BorderRadius.circular(4)),
          child: FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: pct,
            child: Container(decoration: BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF13B5EA), Color(0xFF2C6CFF)]), borderRadius: BorderRadius.circular(4))))),
        SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('$_mastered of $_total skills mastered', style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.54), fontSize: 13)),
          Text('$unmastered to go', style: TextStyle(color: Color(0xFF13B5EA), fontSize: 13, fontWeight: FontWeight.w600)),
        ]),
        // ── Mastered Skills Tags ──
        if (masteredNames.isNotEmpty) ...[
          SizedBox(height: 16),
          Divider(color: theme.dividerColor, height: 1),
          SizedBox(height: 12),
          Row(children: [
            Icon(Icons.emoji_events, color: Color(0xFF00C896), size: 18),
            SizedBox(width: 6),
            Text('Mastered', style: TextStyle(color: Color(0xFF00C896), fontSize: 13, fontWeight: FontWeight.bold)),
          ]),
          SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: masteredNames.map((name) => Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Color(0xFF00C896).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Color(0xFF00C896).withValues(alpha: 0.4)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.check_circle, color: Color(0xFF00C896), size: 14),
                SizedBox(width: 4),
                Text(name, style: TextStyle(color: Color(0xFF00C896), fontSize: 12, fontWeight: FontWeight.w500)),
              ]),
            )).toList(),
          ),
        ],
      ]),
    );
  }

  Widget _buildSkillGroups(ThemeData theme, bool isDark) {
    if (_grouped.isEmpty && _masteredGroups.isEmpty) {
      return Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: BorderRadius.circular(20)),
        child: Text('No skills yet. Upload a CV or tap + to add!', style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.54))),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._grouped.map((g) => _buildGroupCard(g, theme, isDark)),
        ..._masteredGroups.map((g) => _buildGroupCard(g, theme, isDark)),
      ],
    );
  }

  Widget _buildGroupCard(Map<String, dynamic> groupData, ThemeData theme, bool isDark) {
    final groupName = groupData['group'] as String? ?? 'General';
    final percentage = groupData['percentage'] as int? ?? 0;
    final skills = List<Map<String, dynamic>>.from(groupData['skills'] as List? ?? []);

    return Container(
      margin: EdgeInsets.only(bottom: 24),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark ? [] : [BoxShadow(color: Colors.black12, blurRadius: 10)]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(groupName, style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold))),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$percentage%', style: TextStyle(color: percentage == 100 ? Color(0xFF00C896) : Color(0xFF13B5EA), fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(width: 8),
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(color: Color(0xFF13B5EA).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: Icon(Icons.add, color: Color(0xFF13B5EA), size: 18),
                      onPressed: () => _showAddDialog(prefilledCategory: groupName == 'General' ? null : groupName),
                      tooltip: 'Add sub-skill',
                    ),
                  ),
                ],
              ),
            ]
          ),
          SizedBox(height: 12),
          Container(
            height: 6,
            decoration: BoxDecoration(color: theme.dividerColor, borderRadius: BorderRadius.circular(3)),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: percentage / 100,
              child: Container(decoration: BoxDecoration(color: percentage == 100 ? Color(0xFF00C896) : Color(0xFF13B5EA), borderRadius: BorderRadius.circular(3))),
            )
          ),
          SizedBox(height: 16),
          ...skills.map((s) => _buildSkillItem(s, theme)),
        ]
      )
    );
  }

  Widget _buildSkillItem(Map<String, dynamic> skill, ThemeData theme) {
    final isChecked = skill['isChecked'] as bool;
    return GestureDetector(
      onTap: () => _toggleSkill(skill),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        margin: EdgeInsets.only(bottom: 8),
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4), // Reduced padding since IconButton has padding
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Row(children: [
          SizedBox(width: 8),
          Icon(
            isChecked ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isChecked ? Color(0xFF13B5EA) : theme.colorScheme.onSurface.withValues(alpha: 0.24),
            size: 20,
          ),
          SizedBox(width: 12),
          Expanded(child: Text(skill['name'] ?? '', style: TextStyle(
            color: theme.colorScheme.onSurface, fontSize: 15,
            decoration: isChecked ? TextDecoration.lineThrough : null,
            decorationColor: theme.colorScheme.onSurface.withValues(alpha: 0.3),
          ))),
          IconButton(
            icon: Icon(Icons.more_vert, color: theme.colorScheme.onSurface.withValues(alpha: 0.54), size: 20),
            onPressed: () => _showSkillActionSheet(skill),
          ),
        ]),
      ),
    );
  }

  Widget _buildError() {
    final theme = Theme.of(context);
    return Center(child: Padding(padding: EdgeInsets.all(32), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.wifi_off, color: theme.colorScheme.onSurface.withValues(alpha: 0.38), size: 56),
      SizedBox(height: 16),
      Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.54), fontSize: 14)),
      SizedBox(height: 24),
      ElevatedButton.icon(onPressed: _fetchSkills, icon: Icon(Icons.refresh), label: Text('Retry'), style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF13B5EA), foregroundColor: Colors.white)),
    ])));
  }
}