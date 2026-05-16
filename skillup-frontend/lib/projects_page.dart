import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api_service.dart';
import 'user_session.dart';

class ProjectsPage extends StatefulWidget {
  const ProjectsPage({super.key});

  @override
  State<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends State<ProjectsPage> {
  bool _isLoading = true;
  String? _error;

  List<Map<String, dynamic>> _projects = [];
  int _totalProjects = 0;
  int _categories = 0;
  int _totalLinks = 0;

  @override
  void initState() {
    super.initState();
    _fetchProjects();
  }

  Future<void> _fetchProjects() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final session = UserSession.instance;
      final data =
          await ApiService.instance.getProjects(session.userId, session.token);
      if (mounted) {
        setState(() {
          _projects =
              List<Map<String, dynamic>>.from(data['projects'] as List? ?? []);
          
          _totalProjects = _projects.length;
          final allTags = <String>{};
          int linkCount = 0;
          for (final p in _projects) {
            final tags = List<String>.from(p['tags'] as List? ?? []);
            allTags.addAll(tags);
            final links = List<Map<String, dynamic>>.from(p['links'] as List? ?? []);
            linkCount += links.length;
          }
          _categories = allTags.length;
          _totalLinks = linkCount;
          
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Cannot reach backend. Is the server running?';
          _isLoading = false;
        });
      }
    }
  }

  void _showAddProjectDialog() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final tagsCtrl = TextEditingController();
    
    // Dynamic links state
    List<TextEditingController> urlCtrls = [];
    List<String> linkTypes = [];

    void addLinkRow() {
      urlCtrls.add(TextEditingController());
      linkTypes.add('Website'); // Default
    }

    // Add one empty link by default
    addLinkRow();

    bool isFetching = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final theme = Theme.of(context);
            return AlertDialog(
              backgroundColor: theme.colorScheme.surface,
              title: Text('Add New Project',
                  style: TextStyle(color: theme.colorScheme.onSurface)),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _dialogField(titleCtrl, 'Title', Icons.title),
                      const SizedBox(height: 12),
                      _dialogField(descCtrl, 'Description', Icons.description,
                          maxLines: 3),
                      const SizedBox(height: 12),
                      _dialogField(tagsCtrl, 'Tags (comma separated)',
                          Icons.label_outline),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Links', style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                          TextButton.icon(
                            onPressed: () {
                              setStateDialog(() {
                                addLinkRow();
                              });
                            },
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Add Link'),
                          )
                        ],
                      ),
                      ...List.generate(urlCtrls.length, (index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: DropdownButtonFormField<String>(
                                  value: linkTypes[index],
                                  isExpanded: true,
                                  icon: const Icon(Icons.arrow_drop_down, size: 16),
                                  items: ['Website', 'Figma', 'Behance', 'Video', 'Demo', 'GitHub', 'Other']
                                      .map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)))
                                      .toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setStateDialog(() => linkTypes[index] = val);
                                    }
                                  },
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                                    filled: true,
                                    fillColor: theme.scaffoldBackgroundColor,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 5,
                                child: _dialogField(urlCtrls[index], 'URL', Icons.link),
                              ),
                              if (linkTypes[index] == 'GitHub')
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  icon: isFetching ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome, size: 20),
                                  tooltip: 'Auto-fill from README',
                                  onPressed: isFetching ? null : () async {
                                    final url = urlCtrls[index].text.trim();
                                    if (url.isEmpty || !url.contains('github.com')) return;
                                    setStateDialog(() => isFetching = true);
                                    try {
                                      final session = UserSession.instance;
                                      final res = await ApiService.instance.fetchReadme(repoUrl: url, token: session.token);
                                      if (res['tags'] != null) {
                                        final extractedTags = List<String>.from(res['tags']);
                                        if (extractedTags.isNotEmpty) {
                                          final currentTags = tagsCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                                          currentTags.addAll(extractedTags);
                                          tagsCtrl.text = currentTags.toSet().join(', ');
                                          if (ctx.mounted) {
                                            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Extracted tags: ${extractedTags.join(', ')}'), backgroundColor: Colors.green));
                                          }
                                        } else {
                                          if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('No relevant tags found in README')));
                                        }
                                      }
                                    } catch (e) {
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Failed to fetch README')));
                                      }
                                    } finally {
                                      setStateDialog(() => isFetching = false);
                                    }
                                  },
                                ),
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 32),
                                icon: const Icon(Icons.close, size: 18, color: Colors.red),
                                onPressed: () {
                                  setStateDialog(() {
                                    urlCtrls.removeAt(index);
                                    linkTypes.removeAt(index);
                                  });
                                },
                              )
                            ],
                          ),
                        );
                      })
                    ],
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancel',
                      style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.54))),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      backgroundColor: const Color(0xFF13B5EA),
                      foregroundColor: Colors.white),
                  onPressed: () async {
                    if (titleCtrl.text.isEmpty || descCtrl.text.isEmpty) return;
                    Navigator.pop(ctx);
                    final session = UserSession.instance;
                    final tags = tagsCtrl.text
                        .split(',')
                        .map((t) => t.trim())
                        .where((t) => t.isNotEmpty)
                        .toList();
                    
                    final linksData = <Map<String, String>>[];
                    for (int i = 0; i < urlCtrls.length; i++) {
                      final url = urlCtrls[i].text.trim();
                      if (url.isNotEmpty) {
                        linksData.add({'type': linkTypes[i], 'url': url});
                      }
                    }

                    await ApiService.instance.createProject(
                      userId: session.userId,
                      title: titleCtrl.text.trim(),
                      description: descCtrl.text.trim(),
                      tags: tags,
                      links: linksData,
                      token: session.token,
                    );
                    _fetchProjects();
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  Widget _dialogField(TextEditingController ctrl, String hint, IconData icon,
      {int maxLines = 1}) {
    final theme = Theme.of(context);
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: TextStyle(color: theme.colorScheme.onSurface),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.38)),
        prefixIcon: Icon(icon, color: theme.colorScheme.onSurface.withValues(alpha: 0.38), size: 18),
        filled: true,
        fillColor: theme.scaffoldBackgroundColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF13B5EA)))
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _fetchProjects,
                  color: const Color(0xFF13B5EA),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- Header ---
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('My Projects',
                                    style: TextStyle(
                                        color: theme.colorScheme.onSurface,
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text(
                                  '$_totalProjects project${_totalProjects == 1 ? '' : 's'} showcased',
                                  style: TextStyle(
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.54), fontSize: 15),
                                ),
                              ],
                            ),
                            GestureDetector(
                              onTap: _showAddProjectDialog,
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                    color: const Color(0xFF13B5EA),
                                    borderRadius: BorderRadius.circular(14)),
                                child: const Icon(Icons.add, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),

                        // --- Projects list ---
                        if (_projects.isEmpty)
                          _buildAddProjectCard()
                        else ...[
                          for (final p in _projects) _buildProjectCard(p),
                          _buildAddProjectCard(),
                        ],

                        // --- Stats ---
                        Row(
                          children: [
                            _buildStatCard('$_totalProjects', 'Projects',
                                const Color(0xFF13B5EA)),
                            _buildStatCard(
                                '$_categories', 'Categories', const Color(0xFFFF2E93)),
                            _buildStatCard('$_totalLinks', 'Links',
                                const Color(0xFFB066FF)),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildError() {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off, color: theme.colorScheme.onSurface.withValues(alpha: 0.38), size: 56),
            const SizedBox(height: 16),
            Text(_error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.54), fontSize: 14)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchProjects,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF13B5EA),
                  foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditProjectDialog(Map<String, dynamic> project) {
    final titleCtrl = TextEditingController(text: project['title'] ?? '');
    final descCtrl = TextEditingController(text: project['description'] ?? '');
    final tagsCtrl = TextEditingController(
      text: (project['tags'] as List<dynamic>?)?.join(', ') ?? '',
    );
    
    // Dynamic links state
    List<TextEditingController> urlCtrls = [];
    List<String> linkTypes = [];

    // Pre-fill existing links
    final existingLinks = List<Map<String, dynamic>>.from(project['links'] as List? ?? []);
    for (final link in existingLinks) {
      urlCtrls.add(TextEditingController(text: link['url'] ?? ''));
      linkTypes.add(link['type'] ?? 'Website');
    }

    // Add one empty link by default if no links exist
    if (urlCtrls.isEmpty) {
      urlCtrls.add(TextEditingController());
      linkTypes.add('Website');
    }

    bool isFetching = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final theme = Theme.of(context);
            return AlertDialog(
              backgroundColor: theme.colorScheme.surface,
              title: Text('Edit Project',
                  style: TextStyle(color: theme.colorScheme.onSurface)),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _dialogField(titleCtrl, 'Title', Icons.title),
                      const SizedBox(height: 12),
                      _dialogField(descCtrl, 'Description', Icons.description,
                          maxLines: 3),
                      const SizedBox(height: 12),
                      _dialogField(tagsCtrl, 'Tags (comma separated)',
                          Icons.label_outline),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Links', style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                          TextButton.icon(
                            onPressed: () {
                              setStateDialog(() {
                                urlCtrls.add(TextEditingController());
                                linkTypes.add('Website');
                              });
                            },
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Add Link'),
                          )
                        ],
                      ),
                      ...List.generate(urlCtrls.length, (index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: DropdownButtonFormField<String>(
                                  value: linkTypes[index],
                                  isExpanded: true,
                                  icon: const Icon(Icons.arrow_drop_down, size: 16),
                                  items: ['Website', 'Figma', 'Behance', 'Video', 'Demo', 'GitHub', 'Other']
                                      .map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)))
                                      .toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setStateDialog(() => linkTypes[index] = val);
                                    }
                                  },
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                                    filled: true,
                                    fillColor: theme.scaffoldBackgroundColor,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 5,
                                child: _dialogField(urlCtrls[index], 'URL', Icons.link),
                              ),
                              if (linkTypes[index] == 'GitHub')
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  icon: isFetching ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome, size: 20),
                                  tooltip: 'Auto-fill from README',
                                  onPressed: isFetching ? null : () async {
                                    final url = urlCtrls[index].text.trim();
                                    if (url.isEmpty || !url.contains('github.com')) return;
                                    setStateDialog(() => isFetching = true);
                                    try {
                                      final session = UserSession.instance;
                                      final res = await ApiService.instance.fetchReadme(repoUrl: url, token: session.token);
                                      if (res['tags'] != null) {
                                        final extractedTags = List<String>.from(res['tags']);
                                        if (extractedTags.isNotEmpty) {
                                          final currentTags = tagsCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                                          currentTags.addAll(extractedTags);
                                          tagsCtrl.text = currentTags.toSet().join(', ');
                                          if (ctx.mounted) {
                                            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Extracted tags: ${extractedTags.join(', ')}'), backgroundColor: Colors.green));
                                          }
                                        } else {
                                          if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('No relevant tags found in README')));
                                        }
                                      }
                                    } catch (e) {
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Failed to fetch README')));
                                      }
                                    } finally {
                                      setStateDialog(() => isFetching = false);
                                    }
                                  },
                                ),
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 32),
                                icon: const Icon(Icons.close, size: 18, color: Colors.red),
                                onPressed: () {
                                  setStateDialog(() {
                                    urlCtrls.removeAt(index);
                                    linkTypes.removeAt(index);
                                  });
                                },
                              )
                            ],
                          ),
                        );
                      })
                    ],
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancel',
                      style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.54))),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      backgroundColor: const Color(0xFF13B5EA),
                      foregroundColor: Colors.white),
                  onPressed: () async {
                    if (titleCtrl.text.isEmpty || descCtrl.text.isEmpty) return;
                    Navigator.pop(ctx);
                    final session = UserSession.instance;
                    final tags = tagsCtrl.text
                        .split(',')
                        .map((t) => t.trim())
                        .where((t) => t.isNotEmpty)
                        .toList();
                    
                    final linksData = <Map<String, String>>[];
                    for (int i = 0; i < urlCtrls.length; i++) {
                      final url = urlCtrls[i].text.trim();
                      if (url.isNotEmpty) {
                        linksData.add({'type': linkTypes[i], 'url': url});
                      }
                    }

                    await ApiService.instance.updateProject(
                      id: (project['id'] as num).toInt(),
                      title: titleCtrl.text.trim(),
                      description: descCtrl.text.trim(),
                      tags: tags,
                      links: linksData,
                      token: session.token,
                    );
                    _fetchProjects();
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  void _showDeleteConfirmationDialog(Map<String, dynamic> project) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          title: Text('Delete Project',
              style: TextStyle(color: theme.colorScheme.onSurface)),
          content: Text(
            'Are you sure you want to delete "${project['title']}"? This action cannot be undone.',
            style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.54))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(ctx);
                final session = UserSession.instance;
                await ApiService.instance.deleteProject(
                  id: (project['id'] as num).toInt(),
                  token: session.token,
                );
                _fetchProjects();
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProjectCard(Map<String, dynamic> p) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tags = List<String>.from(p['tags'] as List? ?? []);
    final links = List<Map<String, dynamic>>.from(p['links'] as List? ?? []);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isDark ? [] : [const BoxShadow(color: Colors.black12, blurRadius: 10)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.folder_special, color: theme.colorScheme.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(p['title'] ?? '',
                    style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
              ),
              // Edit button
              IconButton(
                icon: Icon(Icons.edit, color: theme.colorScheme.onSurface.withValues(alpha: 0.54), size: 20),
                tooltip: 'Edit project',
                onPressed: () => _showEditProjectDialog(p),
              ),
              // Delete button
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                tooltip: 'Delete project',
                onPressed: () => _showDeleteConfirmationDialog(p),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(p['description'] ?? '',
              style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.54), fontSize: 13, height: 1.4)),
          const SizedBox(height: 16),
          Wrap(children: tags.map((t) => _buildChip(t)).toList()),
          if (links.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: links.map((link) {
                return _buildButton(link['type'] ?? 'Link', link['url'] ?? '', link['type'] == 'Demo');
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChip(String label) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(right: 8, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.dividerColor, width: 0.5)),
      child: Text(label,
          style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 11)),
    );
  }

  Widget _buildButton(String label, String url, bool isPrimary) {
    final theme = Theme.of(context);
    
    Widget buildIcon() {
      if (label.toLowerCase() == 'github') {
        return Image.asset('assets/github.png', width: 16, height: 16, color: isPrimary ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.7));
      } else if (label.toLowerCase() == 'figma') {
        return Image.asset('assets/figma.png', width: 16, height: 16);
      } else if (label.toLowerCase() == 'behance') {
        return Image.asset('assets/behance.png', width: 16, height: 16);
      } else {
        IconData iconData;
        switch (label) {
          case 'Video': iconData = Icons.play_circle_outline; break;
          default: iconData = Icons.open_in_new;
        }
        return Icon(iconData,
            size: 16,
            color: isPrimary
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface.withValues(alpha: 0.7));
      }
    }

    return GestureDetector(
      onTap: () async {
        if (url.isNotEmpty) {
          final uri = Uri.parse(url.startsWith('http') ? url : 'https://$url');
          try {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open link')));
            }
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isPrimary
              ? theme.colorScheme.primary.withValues(alpha: 0.15)
              : theme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.dividerColor, width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            buildIcon(),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: isPrimary
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w500,
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildAddProjectCard() {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: _showAddProjectDialog,
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor, width: 2),
        ),
        child: Center(
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.add, color: theme.colorScheme.onSurface.withValues(alpha: 0.54)),
              ),
              const SizedBox(height: 16),
              Text('Add New Project',
                  style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('Showcase your latest work',
                  style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.54), fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String value, String label, Color color) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isDark ? [] : [const BoxShadow(color: Colors.black12, blurRadius: 10)]),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: 24,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.54), fontSize: 11)),
          ],
        ),
      ),
    );
  }
}