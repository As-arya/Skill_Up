import 'package:flutter/material.dart';
import 'api_service.dart';
import 'user_session.dart';
import 'notification_service.dart';

class SkillPage extends StatefulWidget {
  const SkillPage({super.key});
  @override
  State<SkillPage> createState() => _SkillPageState();
}

class _SkillPageState extends State<SkillPage> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _skills = [];
  int _mastered = 0, _total = 0;
  bool _editMode = false;

  @override
  void initState() { super.initState(); _fetchSkills(); }

  Future<void> _fetchSkills() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final s = UserSession.instance;
      final data = await ApiService.instance.getSkills(s.userId, s.token);
      if (mounted) {
        setState(() {
          _skills = List<Map<String, dynamic>>.from(data['skills'] as List? ?? []);
          _total = _skills.length;
          _mastered = _skills.where((s) => s['isChecked'] == true).length;
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
      setState(() {
        skill['isChecked'] = nv;
        _mastered = _skills.where((s) => s['isChecked'] == true).length;
      });
    }
  }

  bool _isCoreSkill(Map<String, dynamic> skill) => skill['isChecked'] == true;

  // ─── FAB Actions ─────────────────────────────────────────

  void _showAddDialog() {
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(children: [
        Icon(Icons.add_circle, color: Color(0xFF13B5EA), size: 22),
        SizedBox(width: 8),
        Text('Add Skill', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18)),
      ]),
      content: TextField(
        controller: ctrl, autofocus: true,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        decoration: InputDecoration(
          hintText: 'e.g., Docker, Figma, TypeScript',
          hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38)),
          filled: true, fillColor: Theme.of(context).scaffoldBackgroundColor,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54)))),
        ElevatedButton(
          onPressed: () async {
            final name = ctrl.text.trim();
            if (name.isEmpty) return;
            Navigator.pop(ctx);
            try {
              final ses = UserSession.instance;
              await ApiService.instance.createSkill(userId: ses.userId, name: name, isChecked: false, token: ses.token);
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
          ListTile(leading: Icon(Icons.notifications_active_outlined, color: Color(0xFFFF9800)), title: Text('Set Reminder', style: TextStyle(color: theme.colorScheme.onSurface)), onTap: () {
            Navigator.pop(ctx);
            NotificationService().scheduleLearningReminder(id: skill['id'] ?? 0, title: '📚 SkillUp Reminder', body: 'Time to practice: ${skill['name']}!', hour: 9, minute: 0);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Reminder set for "${skill['name']}" at 9:00 AM'), backgroundColor: Color(0xFF13B5EA)));
          }),
          ListTile(leading: Icon(Icons.delete_outline, color: Colors.redAccent), title: Text('Delete', style: TextStyle(color: Colors.redAccent)), onTap: () { Navigator.pop(ctx); _showDeleteDialog(skill); }),
        ]),
      )),
    );
  }

  void _showFabMenu() {
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
          Text('Manage Skills', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 18)),
          SizedBox(height: 8),
          ListTile(leading: Icon(Icons.add_circle_outline, color: Color(0xFF13B5EA)), title: Text('Add New Skill', style: TextStyle(color: theme.colorScheme.onSurface)), subtitle: Text('Add a custom skill to track', style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.54), fontSize: 12)), onTap: () { Navigator.pop(ctx); _showAddDialog(); }),
          Divider(height: 1, indent: 56),
          ListTile(
            leading: Icon(_editMode ? Icons.check_circle : Icons.edit_outlined, color: _editMode ? Colors.green : Color(0xFFFF9800)),
            title: Text(_editMode ? 'Done Editing' : 'Edit / Delete Skills', style: TextStyle(color: theme.colorScheme.onSurface)),
            subtitle: Text(_editMode ? 'Exit edit mode' : 'Tap any skill to rename or delete', style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.54), fontSize: 12)),
            onTap: () { Navigator.pop(ctx); setState(() => _editMode = !_editMode); },
          ),
        ]),
      )),
    );
  }

  // ─── BUILD ───────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final progressPercent = _total > 0 ? (_mastered / _total) : 0.0;
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
          onPressed: _showFabMenu,
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Icon(_editMode ? Icons.check : Icons.edit, color: Colors.white),
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
                    Text(_editMode ? 'Tap a skill to edit or delete' : 'Track your mastered skills', style: TextStyle(color: _editMode ? Color(0xFFFF9800) : theme.colorScheme.onSurface.withValues(alpha: 0.54), fontSize: 15)),
                    SizedBox(height: 24),
                    // Progress Card
                    _buildProgressCard(theme, isDark, progressPercent, unmastered),
                    SizedBox(height: 24),
                    // Skills List
                    _buildSkillSection(theme, isDark),
                    SizedBox(height: 24),
                    // Improvement Section
                    _buildImprovementSection(theme, isDark),
                  ]),
                ),
              ),
      ),
    );
  }

  Widget _buildProgressCard(ThemeData theme, bool isDark, double pct, int unmastered) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: BorderRadius.circular(20), boxShadow: isDark ? [] : [BoxShadow(color: Colors.black12, blurRadius: 10)]),
      child: Column(children: [
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
      ]),
    );
  }

  Widget _buildSkillSection(ThemeData theme, bool isDark) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: BorderRadius.circular(20), boxShadow: isDark ? [] : [BoxShadow(color: Colors.black12, blurRadius: 10)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: Color(0xFF13B5EA), shape: BoxShape.circle)),
          SizedBox(width: 8),
          Text('Your Skills', style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.w600)),
          Spacer(),
          if (_editMode) Container(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Color(0xFFFF9800).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
            child: Text('EDIT MODE', style: TextStyle(color: Color(0xFFFF9800), fontSize: 10, fontWeight: FontWeight.bold))),
        ]),
        SizedBox(height: 16),
        if (_skills.isEmpty) Text('No skills yet. Upload a CV or tap + to add!', style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.54)))
        else ...(_skills.map((s) => _buildSkillItem(s, theme))),
      ]),
    );
  }

  Widget _buildSkillItem(Map<String, dynamic> skill, ThemeData theme) {
    final isChecked = skill['isChecked'] as bool;
    return GestureDetector(
      onTap: _editMode ? () => _showSkillActionSheet(skill) : () => _toggleSkill(skill),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        margin: EdgeInsets.only(bottom: 8),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _editMode ? Color(0xFFFF9800).withValues(alpha: 0.06) : theme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _editMode ? Color(0xFFFF9800).withValues(alpha: 0.3) : theme.dividerColor),
        ),
        child: Row(children: [
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
          if (_editMode) Icon(Icons.more_horiz, color: Color(0xFFFF9800), size: 20),
        ]),
      ),
    );
  }

  Widget _buildImprovementSection(ThemeData theme, bool isDark) {
    final toImprove = _skills.where((s) => s['isChecked'] == false).toList();
    if (toImprove.isEmpty) {
      return Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(color: isDark ? Color(0xFF0E2A1A) : Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(20), border: Border.all(color: Color(0xFF00C896).withValues(alpha: 0.3))),
        child: Row(children: [
          Icon(Icons.check_circle, color: Color(0xFF00C896), size: 20), SizedBox(width: 12),
          Text('All skills mastered! Great job 🎉', style: TextStyle(color: Color(0xFF00C896), fontSize: 14)),
        ]),
      );
    }
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(color: isDark ? Color(0xFF2A1616) : Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(20), border: Border.all(color: Color(0xFFE65C00).withValues(alpha: 0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.error_outline, color: Color(0xFFFF9800), size: 20), SizedBox(width: 8),
          Text('Skills to Improve', style: TextStyle(color: Color(0xFFFF9800), fontSize: 16, fontWeight: FontWeight.w600)),
        ]),
        SizedBox(height: 16),
        for (final skill in toImprove)
          Padding(padding: EdgeInsets.only(bottom: 8, left: 4),
            child: Row(children: [
              Container(width: 6, height: 6, decoration: BoxDecoration(color: Color(0xFFFF9800), shape: BoxShape.circle)),
              SizedBox(width: 12),
              Expanded(child: Text(skill['name'] ?? '', style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 14))),
            ]),
          ),
      ]),
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