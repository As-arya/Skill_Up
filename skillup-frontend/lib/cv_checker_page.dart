import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'loading_overlay.dart';
import 'api_service.dart';
import 'user_session.dart';

class CvCheckerPage extends StatefulWidget {
  const CvCheckerPage({super.key});

  @override
  State<CvCheckerPage> createState() => _CvCheckerPageState();
}

class _CvCheckerPageState extends State<CvCheckerPage> {
  bool _isAnalyzing = false;
  Map<String, dynamic>? _result;
  DateTime? _lastRequestTime;
  static const _cooldown = Duration(seconds: 3);

  bool _canRequest() {
    if (_isAnalyzing) return false;
    if (_lastRequestTime != null &&
        DateTime.now().difference(_lastRequestTime!) < _cooldown) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait a moment before trying again.'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return false;
    }
    return true;
  }

  Future<void> _uploadAndAnalyzeFile() async {
    if (!_canRequest()) return;

    if (Platform.isAndroid) {
      var status = await Permission.storage.status;
      if (!status.isGranted) status = await Permission.storage.request();
      if (!status.isGranted) {
        var photosStatus = await Permission.photos.status;
        if (!photosStatus.isGranted) {
          photosStatus = await Permission.photos.request();
        }
        if (!photosStatus.isGranted) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Storage permission is required to upload CV.'),
              backgroundColor: Colors.redAccent,
            ),
          );
          return;
        }
      }
    }

    FilePickerResult? fileResult = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (fileResult == null || fileResult.files.single.path == null) return;

    setState(() {
      _isAnalyzing = true;
      _result = null;
      _lastRequestTime = DateTime.now();
    });

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

      final session = UserSession.instance;
      final data = await ApiService.instance.analyzeCV(
        userId: session.userId,
        cvContent: extractedText,
        imageBase64: imageBase64,
        mimeType: mimeType,
        token: session.token,
      );

      // Defensive: handle unexpected response shapes
      Map<String, dynamic> result;
      if (data.containsKey('detectedRole') || data.containsKey('overallScore')) {
        result = data;
      } else if (data.containsKey('isTechCV')) {
        // Legacy format — strip isTechCV fields and normalize
        result = {
          'detectedRole': data['detectedRole'] ?? 'Unknown',
          'overallScore': data['overallScore'],
          'summary': data['summary'] ?? '',
          'strengths': data['strengths'] ?? <String>[],
          'weaknesses': data['weaknesses'] ?? data['missingForTech'] ?? <String>[],
          'recommendations': data['recommendations'] ?? <String>[],
          'formattingNotes': data['formattingNotes'] ?? '',
        };
      } else if (data.containsKey('feedback')) {
        result = {
          'detectedRole': 'Unknown',
          'overallScore': null,
          'summary': data['feedback'] as String? ?? '',
          'strengths': <String>[],
          'weaknesses': <String>[],
          'recommendations': <String>[],
          'formattingNotes': '',
        };
      } else {
        result = {
          'detectedRole': 'Unknown',
          'overallScore': null,
          'summary': data.toString(),
          'strengths': <String>[],
          'weaknesses': <String>[],
          'recommendations': <String>[],
          'formattingNotes': '',
        };
      }

      setState(() {
        _result = result;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      setState(() {
        _isAnalyzing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('CV Checker'),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'AI-powered CV analysis',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.54),
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Upload card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: isDark
                          ? []
                          : [const BoxShadow(color: Colors.black12, blurRadius: 10)],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Upload Your CV',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
                              border: Border.all(
                                color: theme.dividerColor,
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.upload_file,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.54),
                                  size: 32,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Upload CV',
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'PDF or Image (max 5MB)',
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.38),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Results
                  if (_result != null) ...[
                    const SizedBox(height: 32),
                    _CvResultView(data: _result!, isDark: isDark),
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
}

// ─── Result View ──────────────────────────────────────────────

class _CvResultView extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isDark;

  const _CvResultView({required this.data, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final detectedRole = data['detectedRole'] as String? ?? '';
    final score = data['overallScore'] as int?;
    final summary = data['summary'] as String? ?? '';
    final strengths = _toList(data['strengths']);
    final weaknesses = _toList(data['weaknesses']);
    final recommendations = _toList(data['recommendations']);
    final formattingNotes = data['formattingNotes'] as String? ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header card: detected role + score badge
        _SectionCard(
          isDark: isDark,
          accentColor: theme.colorScheme.primary,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Detected Role',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      detectedRole.isNotEmpty ? detectedRole : 'Unknown Role',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              if (score != null) _ScoreBadge(score: score),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Summary
        if (summary.isNotEmpty)
          _SectionCard(
            isDark: isDark,
            label: 'Overall Assessment',
            child: Text(
              summary,
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurface,
                height: 1.6,
              ),
            ),
          ),

        const SizedBox(height: 12),

        // Strengths
        if (strengths.isNotEmpty)
          _SectionCard(
            isDark: isDark,
            label: 'Strengths',
            labelColor: Colors.green.shade600,
            child: _BulletList(items: strengths, color: Colors.green.shade600),
          ),

        const SizedBox(height: 12),

        // Areas to Improve
        if (weaknesses.isNotEmpty)
          _SectionCard(
            isDark: isDark,
            label: 'Areas to Improve',
            labelColor: Colors.red.shade400,
            child: _BulletList(items: weaknesses, color: Colors.red.shade400),
          ),

        const SizedBox(height: 12),

        // Recommendations
        if (recommendations.isNotEmpty)
          _SectionCard(
            isDark: isDark,
            label: 'Recommendations',
            labelColor: Colors.blue.shade400,
            child: _BulletList(items: recommendations, color: Colors.blue.shade400),
          ),

        const SizedBox(height: 12),

        // Formatting notes
        if (formattingNotes.isNotEmpty)
          _SectionCard(
            isDark: isDark,
            label: 'Formatting Notes',
            child: Text(
              formattingNotes,
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                height: 1.6,
              ),
            ),
          ),

        const SizedBox(height: 24),
      ],
    );
  }

  List<String> _toList(dynamic value) {
    if (value == null) return [];
    if (value is List) return value.map((e) => e.toString()).toList();
    return [];
  }
}

// ─── Score Badge ──────────────────────────────────────────────

class _ScoreBadge extends StatelessWidget {
  final int score;

  const _ScoreBadge({required this.score});

  Color _scoreColor() {
    if (score >= 75) return Colors.green.shade500;
    if (score >= 50) return Colors.orange.shade500;
    return Colors.red.shade400;
  }

  @override
  Widget build(BuildContext context) {
    final color = _scoreColor();
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2.5),
        color: color.withValues(alpha: 0.1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$score',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            'Score',
            style: TextStyle(
              fontSize: 9,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section Card ─────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final Widget child;
  final String? label;
  final Color? labelColor;
  final Color? accentColor;
  final bool isDark;

  const _SectionCard({
    required this.child,
    required this.isDark,
    this.label,
    this.labelColor,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveLabelColor =
        labelColor ?? accentColor ?? theme.colorScheme.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: accentColor != null
            ? Border.all(color: accentColor!.withValues(alpha: 0.35), width: 1.2)
            : Border.all(color: theme.dividerColor.withValues(alpha: 0.6)),
        boxShadow: isDark
            ? []
            : [const BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null) ...[
            Text(
              label!.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: effectiveLabelColor,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 10),
          ],
          child,
        ],
      ),
    );
  }
}

// ─── Bullet List ──────────────────────────────────────────────

class _BulletList extends StatelessWidget {
  final List<String> items;
  final Color color;

  const _BulletList({required this.items, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item,
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onSurface,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
