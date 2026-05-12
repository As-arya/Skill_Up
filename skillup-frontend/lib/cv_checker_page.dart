import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
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
  String? _result;
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
        // Image processing
        File file = File(filePath);
        final List<int> bytes = await file.readAsBytes();
        imageBase64 = base64Encode(bytes);
        mimeType = 'image/$extension';
        if (extension == 'jpg') mimeType = 'image/jpeg';
      }

      // Send to backend for AI analysis
      final session = UserSession.instance;
      final data = await ApiService.instance.analyzeCV(
        userId: session.userId,
        cvContent: extractedText,
        imageBase64: imageBase64,
        mimeType: mimeType,
        token: session.token,
      );

      setState(() {
        _result = data['feedback'] ?? 'No feedback provided.';
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
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

    return Stack(
      children: [
        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const SizedBox(height: 20),
                Center(
                  child: Text(
                    'CV Checker',
                    style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'AI-powered CV analysis',
                    style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.54), fontSize: 14),
                  ),
                ),
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
                      Text('Upload Your CV', style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.bold)),
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
                              Text('Upload CV', style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 14)),
                              const SizedBox(height: 4),
                              Text('PDF or Image (max 5MB)', style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.38), fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_result != null) ...[
                  const SizedBox(height: 32),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
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
                            Icon(Icons.lightbulb_outline, color: theme.colorScheme.primary),
                            const SizedBox(width: 8),
                            Text('Constructive Feedback', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: theme.colorScheme.onSurface)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SelectableText(_result!, style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14, height: 1.6)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (_isAnalyzing) const LoadingOverlay(),
      ],
    );
  }
}