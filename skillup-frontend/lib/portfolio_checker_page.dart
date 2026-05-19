import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'loading_overlay.dart';
import 'api_service.dart';
import 'user_session.dart';

class PortfolioCheckerPage extends StatefulWidget {
  const PortfolioCheckerPage({super.key});

  @override
  State<PortfolioCheckerPage> createState() => _PortfolioCheckerPageState();
}

class _PortfolioCheckerPageState extends State<PortfolioCheckerPage> {
  final TextEditingController _urlController = TextEditingController();
  bool _isAnalyzing = false;
  Map<String, dynamic>? _result;
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

  Future<void> _uploadAndAnalyzeFile() async {
    if (!_canRequest()) return;

    FilePickerResult? fileResult = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (fileResult == null || fileResult.files.single.path == null) return;

    setState(() { _isAnalyzing = true; _result = null; _lastRequestTime = DateTime.now(); });

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

      _sendToBackend(
        jobTitle: "Portfolio Analysis",
        content: extractedText,
        imageBase64: imageBase64,
        mimeType: mimeType,
      );
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<void> _analyzeUrl() async {
    if (!_canRequest()) return;

    if (_urlController.text.trim().isEmpty) {
      _showError("Please enter a valid URL first.");
      return;
    }
    setState(() { _isAnalyzing = true; _result = null; _lastRequestTime = DateTime.now(); });
    
    try {
      final session = UserSession.instance;
      final data = await ApiService.instance.scrapePortfolio(
        userId: session.userId,
        jobTitle: "Portfolio Website",
        url: _urlController.text.trim(),
        token: session.token,
      );

      if (mounted) {
        setState(() => _result = data);
        if ((data['masteredSkills'] as List?)?.isNotEmpty == true) {
          _showMasteryConfirmationDialog(List<String>.from(data['masteredSkills']));
        }
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) {
        setState(() => _isAnalyzing = false);
      }
    }
  }

  Future<void> _sendToBackend({
    required String jobTitle,
    String? content,
    String? imageBase64,
    String? mimeType,
  }) async {
    try {
      final session = UserSession.instance;
      final data = await ApiService.instance.analyzePortfolio(
        userId: session.userId,
        jobTitle: jobTitle,
        content: content,
        imageBase64: imageBase64,
        mimeType: mimeType,
        token: session.token,
      );

      if (mounted) {
        setState(() => _result = data);
        if ((data['masteredSkills'] as List?)?.isNotEmpty == true) {
          _showMasteryConfirmationDialog(List<String>.from(data['masteredSkills']));
        }
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) {
        setState(() => _isAnalyzing = false);
      }
    }
  }

  void _showError(String message) {
    setState(() => _isAnalyzing = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.redAccent));
  }

  void _showMasteryConfirmationDialog(List<String> masteredSkills) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text('Skills Proven!', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('We found evidence for these skills in your portfolio. Mark them as mastered in your checklist?', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7))),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: masteredSkills.map((s) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF13B5EA).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF13B5EA).withValues(alpha: 0.5)),
                ),
                child: Text(s, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13)),
              )).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), 
            child: Text('Not Now', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54)))
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _confirmMastery(masteredSkills);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF13B5EA), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('Confirm Mastery', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      )
    );
  }

  Future<void> _confirmMastery(List<String> skills) async {
    setState(() => _isAnalyzing = true);
    try {
      final session = UserSession.instance;
      await ApiService.instance.confirmMastery(userId: session.userId, skillNames: skills, token: session.token);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Skills marked as mastered!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Portfolio Checker'),
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const SizedBox(height: 20),
                Center(child: Text('Portfolio Checker', style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 24, fontWeight: FontWeight.bold))),
                const SizedBox(height: 8),
                Center(child: Text('AI-powered portfolio analysis', style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.54), fontSize: 14))),
                const SizedBox(height: 32),

                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: isDark ? [] : [const BoxShadow(color: Colors.black12, blurRadius: 10)],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Upload Portfolio', style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),

                      InkWell(
                        onTap: _isAnalyzing ? null : _uploadAndAnalyzeFile,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: theme.dividerColor, width: 1.5),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.upload_file, color: theme.colorScheme.onSurface.withValues(alpha: 0.54), size: 32),
                              const SizedBox(height: 12),
                              Text('Tap to Upload Portfolio Files', style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 14)),
                              const SizedBox(height: 4),
                              Text('PDF, ZIP, or multiple files', style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.38), fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      Row(
                        children: [
                          Expanded(child: Divider(color: theme.dividerColor)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text('or', style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.54), fontSize: 12)),
                          ),
                          Expanded(child: Divider(color: theme.dividerColor)),
                        ],
                      ),
                      const SizedBox(height: 24),

                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _urlController,
                              style: TextStyle(color: theme.colorScheme.onSurface),
                              decoration: InputDecoration(
                                hintText: 'Paste portfolio URL',
                                hintStyle: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.38)),
                                filled: true,
                                fillColor: theme.scaffoldBackgroundColor,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Container(
                            height: 48,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: const LinearGradient(colors: [Color(0xFF13B5EA), Color(0xFF2C6CFF)]),
                            ),
                            child: ElevatedButton.icon(
                              onPressed: _isAnalyzing ? null : _analyzeUrl,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                              label: const Text('Analyze', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Results UI
                if (_result != null) ...[
                  const SizedBox(height: 32),
                  _buildResultCard(
                    title: "Portfolio Score", icon: Icons.analytics_outlined, color: Colors.blueAccent,
                    content: Text("${_result!['matchScore'] ?? 0}/100", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                  ),
                  const SizedBox(height: 16),
                  _buildResultCard(
                    title: "Actionable Feedback", icon: Icons.edit_document, color: Colors.greenAccent,
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _buildFeedbackWidgets(theme),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ],
            ),
          ),
        ),
          if (_isAnalyzing) const LoadingOverlay(),
        ],
      ),
    );
  }

  Widget _buildResultCard({required String title, required IconData icon, required Color color, required Widget content}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity, padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
        boxShadow: isDark ? [] : [const BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 22), const SizedBox(width: 12),
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 16),
          content,
        ],
      ),
    );
  }

  List<Widget> _buildFeedbackWidgets(ThemeData theme) {
    final feedback = _result!['cvFeedback'];
    if (feedback == null) return [const Text('No feedback provided.')];

    if (feedback is Map) {
      final strengths = feedback['strengths'] as List? ?? [];
      final weaknesses = feedback['weaknesses'] as List? ?? [];
      final improvements = feedback['improvements'] as List? ?? [];

      return [
        if (strengths.isNotEmpty) _buildFeedbackSection("Kelebihan", strengths, Colors.greenAccent, Icons.thumb_up_alt_outlined, theme),
        if (weaknesses.isNotEmpty) _buildFeedbackSection("Kekurangan", weaknesses, Colors.redAccent, Icons.thumb_down_alt_outlined, theme),
        if (improvements.isNotEmpty) _buildFeedbackSection("Hal yang Perlu Ditingkatkan", improvements, Colors.orangeAccent, Icons.trending_up, theme),
      ];
    } else if (feedback is List) {
      return feedback.map((fb) => _buildFeedbackItem(fb.toString(), Colors.blueAccent, Icons.tips_and_updates_outlined, theme)).toList();
    }
    return [];
  }

  Widget _buildFeedbackSection(String title, List items, Color color, IconData icon, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12, top: 8),
          child: Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14)),
            ],
          ),
        ),
        ...items.map((item) => _buildFeedbackItem(item.toString(), color, icon, theme)),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildFeedbackItem(String text, Color color, IconData icon, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text.replaceAll('•', '').trim(),
              style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface.withValues(alpha: 0.7), height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}