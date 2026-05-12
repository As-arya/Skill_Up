import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'loading_overlay.dart';
import 'api_service.dart';
import 'user_session.dart';

class SkillMatchingPage extends StatefulWidget {
  const SkillMatchingPage({super.key});

  @override
  State<SkillMatchingPage> createState() => _SkillMatchingPageState();
}

class _SkillMatchingPageState extends State<SkillMatchingPage> {
  final TextEditingController _jobController = TextEditingController();
  
  bool _isAnalyzing = false;
  Map<String, dynamic>? _result;
  
  // Variables to hold the uploaded CV data
  String? _cvText;
  String? _cvImageBase64;
  String? _mimeType;
  String? _fileName;

  // Debounce: prevent spam clicks
  DateTime? _lastRequestTime;
  static const _cooldown = Duration(seconds: 3);

  bool _canRequest() {
    if (_isAnalyzing) return false;
    if (_lastRequestTime != null && DateTime.now().difference(_lastRequestTime!) < _cooldown) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait a moment before trying again.'), backgroundColor: Colors.orangeAccent),
      );
      return false;
    }
    return true;
  }

  Future<void> _pickAndExtractCV() async {
    if (!_canRequest()) return;

    FilePickerResult? fileResult = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );

    if (fileResult == null || fileResult.files.single.path == null) return;

    // Show loading overlay while parsing
    setState(() => _isAnalyzing = true);

    try {
      final filePath = fileResult.files.single.path!;
      final extension = filePath.split('.').last.toLowerCase();
      String? extractedText;
      String? imageBase64;
      String? mimeType;

      if (extension == 'pdf') {
        File file = File(filePath);
        final List<int> bytes = await file.readAsBytes();
        final PdfDocument document = PdfDocument(inputBytes: bytes);
        extractedText = PdfTextExtractor(document).extractText();
        document.dispose();
      } else {
        File file = File(filePath);
        final List<int> bytes = await file.readAsBytes();
        imageBase64 = base64Encode(bytes);
        mimeType = 'image/$extension';
        if (extension == 'jpg') mimeType = 'image/jpeg';
      }

      setState(() {
        _cvText = extractedText;
        _cvImageBase64 = imageBase64;
        _mimeType = mimeType;
        _fileName = fileResult.files.single.name;
      });
      
      // Automatically extract skills after picking CV
      await _extractSkillsAndShowDialog(extractedText, imageBase64, mimeType);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error reading file: $e'), backgroundColor: Colors.redAccent)
        );
      }
    } finally {
      setState(() => _isAnalyzing = false);
    }
  }

  Future<void> _extractSkillsAndShowDialog(String? cvText, String? imageBase64, String? mimeType) async {
    try {
      final session = UserSession.instance;
      final data = await ApiService.instance.extractCV(
        userId: session.userId,
        cvContent: cvText,
        imageBase64: imageBase64,
        mimeType: mimeType,
        token: session.token,
      );

      final String targetRole = data['targetRole'] ?? 'Unknown Role';
      final List<dynamic> skillsDynamic = data['topSkills'] ?? [];
      final List<String> extractedSkills = skillsDynamic.map((e) => e.toString()).toList();

      if (mounted) {
        _showEditDialog(targetRole, extractedSkills);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error extracting data: $e'), backgroundColor: Colors.redAccent)
        );
      }
    }
  }

  void _showEditDialog(String initialRole, List<String> initialSkills) {
    final TextEditingController roleController = TextEditingController(text: initialRole);
    List<String> currentSkills = List.from(initialSkills);
    final TextEditingController newSkillController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Theme.of(context).colorScheme.surface,
              title: Text('Confirm Extraction', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Target Role', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7))),
                      SizedBox(height: 8),
                      TextField(
                        controller: roleController,
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SizedBox(height: 16),
                      Text('Top Skills', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7))),
                      SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: currentSkills.map((skill) {
                          return Chip(
                            label: Text(skill, style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                            backgroundColor: const Color(0xFF13B5EA),
                            onDeleted: () {
                              setDialogState(() {
                                currentSkills.remove(skill);
                              });
                            },
                          );
                        }).toList(),
                      ),
                      SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: newSkillController,
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                              decoration: InputDecoration(
                                hintText: 'Add a skill...',
                                hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38)),
                                filled: true,
                                fillColor: Theme.of(context).colorScheme.surface,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.add, color: Color(0xFF13B5EA)),
                            onPressed: () {
                              if (newSkillController.text.trim().isNotEmpty) {
                                setDialogState(() {
                                  currentSkills.add(newSkillController.text.trim());
                                  newSkillController.clear();
                                });
                              }
                            },
                          )
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54))),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _saveExtractedData(roleController.text, currentSkills);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF13B5EA)),
                  child: Text('Save to Profile'),
                ),
              ],
            );
          }
        );
      }
    );
  }

  Future<void> _saveExtractedData(String role, List<String> skills) async {
    setState(() => _isAnalyzing = true);
    try {
      final session = UserSession.instance;
      // 1. Save Learning Target
      await ApiService.instance.createLearningTarget(
        userId: session.userId,
        targetRole: role,
        token: session.token,
      );
      // 2. Save extracted skills
      for (final skill in skills) {
        await ApiService.instance.createSkill(
          userId: session.userId,
          name: skill,
          isChecked: true, // We consider them mastered as they are extracted from CV
          token: session.token,
        );
      }
      
      setState(() {
        _jobController.text = role;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully! Now you can Analyze Match.'), backgroundColor: Colors.green)
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving profile: $e'), backgroundColor: Colors.redAccent)
        );
      }
    } finally {
      setState(() => _isAnalyzing = false);
    }
  }

  Future<void> _addGapToChecklist(String skillName) async {
    try {
      final session = UserSession.instance;
      await ApiService.instance.createSkill(
        userId: session.userId,
        name: skillName,
        isChecked: false,
        token: session.token,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"$skillName" added to your Skill Checklist!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding skill: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _analyzeMatch() async {
    if (!_canRequest()) return;

    if (_jobController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a job position'), backgroundColor: Colors.redAccent)
      );
      return;
    }

    if (_cvText == null || _cvText!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload your CV first'), backgroundColor: Colors.redAccent)
      );
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _result = null;
      _lastRequestTime = DateTime.now();
    });

    try {
      final session = UserSession.instance;
      final data = await ApiService.instance.analyzeMatch(
        userId: session.userId,
        roleDescription: _jobController.text,
        cvContent: _cvText,
        imageBase64: _cvImageBase64,
        mimeType: _mimeType,
        token: session.token,
      );

      if (mounted) {
        setState(() => _result = data);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent)
        );
      }
    } finally {
      setState(() => _isAnalyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24.0),
            child: Column(
              children: [
                SizedBox(height: 20),
                Center(child: Text('Skill Matching', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 24, fontWeight: FontWeight.bold))),
                SizedBox(height: 8),
                Center(child: Text('Find your skill gaps for any job', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54), fontSize: 14))),
                SizedBox(height: 32),
                
                Container(
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface, 
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: Theme.of(context).brightness == Brightness.light ? [BoxShadow(color: Colors.black12, blurRadius: 10)] : [],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Job Position', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.bold)),
                      SizedBox(height: 16),
                      TextField(
                        controller: _jobController,
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                        decoration: InputDecoration(
                          hintText: 'e.g., Frontend Developer, Full Stack Engin...',
                          hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38)),
                          prefixIcon: Icon(Icons.search, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54)),
                          filled: true,
                          fillColor: Theme.of(context).scaffoldBackgroundColor,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                      
                      SizedBox(height: 24),
                      
                      // --- NEW: Upload CV Section ---
                      Text('Your CV', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.bold)),
                      SizedBox(height: 16),
                      InkWell(
                        onTap: _pickAndExtractCV,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: (_cvText != null || _cvImageBase64 != null) ? Theme.of(context).colorScheme.primary : Colors.transparent,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                (_cvText != null || _cvImageBase64 != null) ? Icons.check_circle : Icons.upload_file,
                                color: (_cvText != null || _cvImageBase64 != null) ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _fileName ?? 'Tap to select your CV (PDF or Image)',
                                  style: TextStyle(
                                    color: (_cvText != null || _cvImageBase64 != null) ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // ------------------------------

                      SizedBox(height: 24),
                      
                      Container(
                        width: double.infinity,
                        height: 48,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: LinearGradient(
                            colors: [Color(0xFF13B5EA), Color(0xFF2C6CFF)],
                          ),
                        ),
                        child: ElevatedButton.icon(
                          onPressed: _isAnalyzing ? null : _analyzeMatch,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            disabledBackgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: _isAnalyzing
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.track_changes, color: Colors.white, size: 20),
                          label: Text(_isAnalyzing ? 'Analyzing...' : 'Analyze Match', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      SizedBox(height: 24),
                      Text('Popular positions:', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54), fontSize: 13)),
                      SizedBox(height: 12),
                      Wrap(
                        spacing: 8, runSpacing: 8,
                        children: [
                          _buildChip('Frontend Developer'),
                          _buildChip('Backend Developer'),
                          _buildChip('Full Stack Engineer'),
                          _buildChip('UX Designer'),
                        ],
                      ),
                    ],
                  ),
                ),

                if (_result != null) ...[
                  SizedBox(height: 32),
                  _buildDarkResultCard(
                    title: "Match Score", icon: Icons.analytics_outlined, color: Colors.blueAccent,
                    content: Text("${_result!['matchScore'] ?? 0}%", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                  ),
                  SizedBox(height: 16),
                  _buildDarkResultCard(
                    title: "Skill Gaps to Fill", icon: Icons.radar, color: Colors.orangeAccent,
                    content: Column(
                      children: ((_result!['skillGaps'] as List?) ?? []).map((gap) {
                        final gapText = gap.toString().replaceAll('•', '').trim();
                        final isDark = Theme.of(context).brightness == Brightness.dark;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF2A1C15) : const Color(0xFFFFF3E0),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    gapText,
                                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 13),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => _addGapToChecklist(gapText),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF13B5EA).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.playlist_add, color: Color(0xFF13B5EA), size: 20),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  SizedBox(height: 40),
                ],
              ],
            ),
          ),
        ),
        if (_isAnalyzing) const LoadingOverlay(),
      ],
    );
  }

  Widget _buildChip(String label) {
    return GestureDetector(
      onTap: () => setState(() => _jobController.text = label),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor, borderRadius: BorderRadius.circular(8), border: Border.all(color: Theme.of(context).dividerColor, width: 0.5),
        ),
        child: Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 12)),
      ),
    );
  }

  Widget _buildDarkResultCard({required String title, required IconData icon, required Color color, required Widget content}) {
    return Container(
      width: double.infinity, padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface, 
        borderRadius: BorderRadius.circular(16), 
        boxShadow: Theme.of(context).brightness == Brightness.light ? [BoxShadow(color: Colors.black12, blurRadius: 10)] : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 22), SizedBox(width: 12),
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16)),
            ],
          ),
          SizedBox(height: 16),
          content,
        ],
      ),
    );
  }
}