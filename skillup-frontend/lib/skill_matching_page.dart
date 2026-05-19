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

  // Flag to prevent duplicate autocomplete listener registration
  bool _autocompleteSynced = false;

  // Job autocomplete suggestions — diverse fields
  List<String> _jobSuggestions = [
    // ── Technology & Engineering ──
    'Frontend Developer', 'Backend Developer', 'Full Stack Developer',
    'Full Stack Engineer', 'Software Engineer', 'Mobile Developer',
    'Android Developer', 'iOS Developer', 'Flutter Developer',
    'Web Developer', 'DevOps Engineer', 'Cloud Engineer',
    'Data Scientist', 'Data Analyst', 'Data Engineer',
    'Machine Learning Engineer', 'AI Engineer', 'QA Engineer',
    'Security Engineer', 'Database Administrator', 'Solutions Architect',
    'Technical Lead', 'Game Developer', 'Technical Writer',
    'Embedded Systems Engineer', 'Blockchain Developer', 'Network Engineer',
    'IT Support Specialist', 'Systems Administrator',
    // ── Design & Creative ──
    'UX Designer', 'UI Designer', 'UX/UI Designer', 'Product Designer',
    'Graphic Designer', 'Motion Graphics Designer', 'Illustrator',
    'Interior Designer', 'Fashion Designer', 'Industrial Designer',
    'Video Editor', 'Photographer', 'Animator', 'Art Director',
    'Creative Director', 'Content Creator',
    // ── Business & Management ──
    'Product Manager', 'Project Manager', 'Business Analyst',
    'Management Consultant', 'Operations Manager', 'Supply Chain Manager',
    'Human Resources Manager', 'Recruiter', 'Office Manager',
    'Entrepreneur', 'Business Development Manager', 'Strategy Consultant',
    // ── Marketing & Communications ──
    'Digital Marketing Specialist', 'SEO Specialist', 'Social Media Manager',
    'Content Strategist', 'Copywriter', 'Brand Manager',
    'Public Relations Specialist', 'Marketing Analyst',
    'Email Marketing Specialist', 'Growth Hacker',
    // ── Finance & Accounting ──
    'Financial Analyst', 'Accountant', 'Auditor', 'Investment Banker',
    'Financial Planner', 'Tax Consultant', 'Risk Analyst',
    'Actuary', 'Treasury Analyst',
    // ── Healthcare & Medicine ──
    'Doctor', 'Nurse', 'Pharmacist', 'Dentist', 'Physiotherapist',
    'Medical Laboratory Technologist', 'Public Health Specialist',
    'Clinical Research Coordinator', 'Health Informatics Specialist',
    'Nutritionist',
    // ── Law & Legal ──
    'Lawyer', 'Legal Consultant', 'Paralegal', 'Compliance Officer',
    'Contract Specialist',
    // ── Education & Research ──
    'Teacher', 'Lecturer', 'Education Consultant', 'Research Scientist',
    'Curriculum Developer', 'Academic Advisor', 'Librarian',
    // ── Construction & Architecture ──
    'Civil Engineer', 'Architect', 'Construction Manager',
    'Structural Engineer', 'Urban Planner', 'Quantity Surveyor',
    // ── Media & Journalism ──
    'Journalist', 'News Anchor', 'Podcast Producer', 'Scriptwriter',
    'Film Director', 'Broadcast Engineer',
    // ── Hospitality & Tourism ──
    'Hotel Manager', 'Event Planner', 'Tour Guide', 'Chef',
    'Restaurant Manager',
    // ── Environment & Agriculture ──
    'Environmental Scientist', 'Agricultural Engineer',
    'Sustainability Consultant', 'Wildlife Biologist',
  ];

  // Debounce: prevent spam clicks
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

  @override
  void initState() {
    super.initState();
    _loadJobSuggestions();
  }

  Future<void> _loadJobSuggestions() async {
    try {
      final session = UserSession.instance;
      final jobs = await ApiService.instance.getJobSuggestions(session.token);
      if (mounted && jobs.isNotEmpty) {
        setState(() => _jobSuggestions = jobs);
        debugPrint('[Job Suggestions] Loaded ${jobs.length} job titles from API');
        
        // Log a sample of non-tech jobs to verify they're included
        final nonTechJobs = jobs.where((job) {
          final lowerJob = job.toLowerCase();
          return !lowerJob.contains('developer') &&
                 !lowerJob.contains('engineer') &&
                 !lowerJob.contains('software') &&
                 !lowerJob.contains('data') &&
                 !lowerJob.contains('designer') &&
                 !lowerJob.contains('analyst') &&
                 !lowerJob.contains('architect');
        }).take(10).toList();
        
        if (nonTechJobs.isNotEmpty) {
          debugPrint('[Job Suggestions] Non-tech job samples: ${nonTechJobs.join(', ')}');
        }
        
        // Check if Hotel Manager is in the list
        if (jobs.any((job) => job.toLowerCase().contains('hotel manager'))) {
          debugPrint('[Job Suggestions] ✓ Hotel Manager is in the job suggestions list');
        } else {
          debugPrint('[Job Suggestions] ✗ Hotel Manager is NOT in the job suggestions list');
        }
      }
    } catch (e) {
      debugPrint('[Job Suggestions] Error loading job suggestions: $e');
      // Keep default suggestions on error
    }
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
          SnackBar(
            content: Text('Error reading file: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      setState(() => _isAnalyzing = false);
    }
  }

  Future<void> _extractSkillsAndShowDialog(
    String? cvText,
    String? imageBase64,
    String? mimeType,
  ) async {
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
      final List<String> extractedSkills = skillsDynamic
          .map((e) => e.toString())
          .toList();

      if (mounted) {
        _showEditDialog(targetRole, extractedSkills);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error extracting data: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showEditDialog(String initialRole, List<String> initialSkills) {
    final TextEditingController roleController = TextEditingController(
      text: initialRole,
    );
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
              title: Text(
                'Confirm Extraction',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Target Role',
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                      SizedBox(height: 8),
                      TextField(
                        controller: roleController,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Top Skills',
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                      SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: currentSkills.map((skill) {
                          return Chip(
                            label: Text(
                              skill,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
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
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Add a skill...',
                                hintStyle: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.38),
                                ),
                                filled: true,
                                fillColor: Theme.of(
                                  context,
                                ).colorScheme.surface,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.add, color: Color(0xFF13B5EA)),
                            onPressed: () {
                              if (newSkillController.text.trim().isNotEmpty) {
                                setDialogState(() {
                                  currentSkills.add(
                                    newSkillController.text.trim(),
                                  );
                                  newSkillController.clear();
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.54),
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _saveExtractedData(
                      roleController.text,
                      currentSkills,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF13B5EA),
                  ),
                  child: Text(
                    'Save to Profile',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
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
          isChecked:
              true, // We consider them mastered as they are extracted from CV
          token: session.token,
        );
      }

      setState(() {
        _jobController.text = role;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Profile updated successfully! Now you can Analyze Match.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving profile: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      setState(() => _isAnalyzing = false);
    }
  }

  Future<void> _analyzeMatch() async {
    if (!_canRequest()) return;

    if (_jobController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a job position'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if ((_cvText == null || _cvText!.isEmpty) &&
        (_cvImageBase64 == null || _cvImageBase64!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload your CV first'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _result = null;
      _lastRequestTime = DateTime.now();
    });

    try {
      // ── Validate Job Title first ──
      final session = UserSession.instance;
      try {
        final jobValidation = await ApiService.instance.validateJob(
          jobTitle: _jobController.text.trim(),
          token: session.token,
        );

        if (jobValidation['valid'] != true) {
          if (mounted) {
            setState(() => _isAnalyzing = false);
            final suggestions =
                (jobValidation['suggestions'] as List?)
                    ?.map((e) => e.toString())
                    .toList() ??
                [];
            _showJobRejectionDialog(
              jobValidation['reason']?.toString() ??
                  'This does not appear to be a valid job position.',
              suggestions,
            );
          }
          return;
        }

        // Auto-correct the job title if the AI has a better version
        final corrected = jobValidation['corrected']?.toString();
        if (corrected != null &&
            corrected.isNotEmpty &&
            corrected != _jobController.text.trim()) {
          // Sanitize the corrected text to remove verbose AI explanations
          String sanitizedCorrected = corrected;
          
          // Pattern 1: "The proper/corrected job title is X, which refers to..."
          final verbosePattern1 = RegExp(r'^(?:The\s+(?:proper|corrected)\s+job\s+title\s+is\s+)?([^,\.]+?)(?:\s*,\s*which\s+refers\s+to|\s*\.|$)', caseSensitive: false);
          final match1 = verbosePattern1.firstMatch(corrected);
          if (match1 != null && match1.group(1) != null) {
            sanitizedCorrected = match1.group(1)!.trim();
          }
          
          // Pattern 2: "X (which is a Y role)" or "X - description"
          final verbosePattern2 = RegExp(r'^([^(—\-]+?)(?:\s*[\(—\-].*)?$');
          final match2 = verbosePattern2.firstMatch(sanitizedCorrected);
          if (match2 != null && match2.group(1) != null) {
            sanitizedCorrected = match2.group(1)!.trim();
          }
          
          // Only update if sanitized version is different and not empty
          if (sanitizedCorrected.isNotEmpty && sanitizedCorrected != _jobController.text.trim()) {
            _jobController.text = sanitizedCorrected;
            debugPrint('[Job Validation] Sanitized corrected title from "$corrected" to "$sanitizedCorrected"');
          } else if (corrected != _jobController.text.trim()) {
            _jobController.text = corrected;
          }
        }
      } catch (e) {
        // If validation fails due to network/timeout, log it but proceed to avoid blocking the user entirely
        debugPrint('Job Validation Error: $e');
      }

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
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      setState(() => _isAnalyzing = false);
    }
  }

  void _showJobRejectionDialog(String reason, List<String> suggestions) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        icon: const Icon(Icons.work_off, color: Colors.orangeAccent, size: 48),
        title: Text(
          'Invalid Job Position',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              reason,
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            if (suggestions.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Did you mean:',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              ...suggestions.map(
                (s) => InkWell(
                  onTap: () {
                    _jobController.text = s;
                    Navigator.pop(context);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.arrow_forward,
                          size: 14,
                          color: Color(0xFF13B5EA),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          s,
                          style: const TextStyle(
                            color: Color(0xFF13B5EA),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Skill Match'),
        elevation: 0,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(24.0),
              child: Column(
                children: [
                  SizedBox(height: 20),
                  Center(
                    child: Text(
                      'Skill Matching',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Find your skill gaps for any job',
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.54),
                        fontSize: 14,
                      ),
                    ),
                  ),
                  SizedBox(height: 32),

                  Container(
                    padding: EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow:
                          Theme.of(context).brightness == Brightness.light
                          ? [BoxShadow(color: Colors.black12, blurRadius: 10)]
                          : [],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Job Position',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 16),
                        Autocomplete<String>(
                          optionsBuilder: (TextEditingValue textEditingValue) {
                            if (textEditingValue.text.isEmpty) {
                              return const Iterable<String>.empty();
                            }
                            final query = textEditingValue.text.toLowerCase();
                            final matches = _jobSuggestions
                                .where(
                                  (job) => job.toLowerCase().contains(query),
                                )
                                .take(6)
                                .toList();
                            debugPrint(
                              '[Autocomplete] Query: "$query" -> ${matches.length} matches',
                            );
                            return matches;
                          },
                          onSelected: (String selection) {
                            debugPrint('[Autocomplete] Selected: $selection');
                            _jobController.text = selection;
                          },
                          fieldViewBuilder:
                              (
                                context,
                                textController,
                                focusNode,
                                onFieldSubmitted,
                              ) {
                                // Sync our _jobController with Autocomplete's textController ONCE
                                if (!_autocompleteSynced) {
                                  _autocompleteSynced = true;
                                  if (_jobController.text.isNotEmpty) {
                                    textController.text = _jobController.text;
                                  }
                                  // Bidirectional sync: autocomplete -> _jobController
                                  textController.addListener(() {
                                    if (_jobController.text !=
                                        textController.text) {
                                      _jobController.text = textController.text;
                                    }
                                  });
                                  // Bidirectional sync: _jobController -> autocomplete (for programmatic updates)
                                  _jobController.addListener(() {
                                    if (textController.text !=
                                        _jobController.text) {
                                      textController.text = _jobController.text;
                                    }
                                  });
                                }
                                return TextField(
                                  controller: textController,
                                  focusNode: focusNode,
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                                  decoration: InputDecoration(
                                    hintText:
                                        'e.g., Frontend Developer, Full Stack Engin...',
                                    hintStyle: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.38),
                                    ),
                                    prefixIcon: Icon(
                                      Icons.search,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.54),
                                    ),
                                    filled: true,
                                    fillColor: Theme.of(
                                      context,
                                    ).scaffoldBackgroundColor,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                );
                              },
                          optionsViewBuilder: (context, onSelected, options) {
                            return Align(
                              alignment: Alignment.topLeft,
                              child: Material(
                                elevation: 8,
                                borderRadius: BorderRadius.circular(12),
                                color: Theme.of(context).colorScheme.surface,
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxHeight: 240,
                                    maxWidth: 340,
                                  ),
                                  child: ListView.builder(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    shrinkWrap: true,
                                    itemCount: options.length,
                                    itemBuilder: (context, index) {
                                      final option = options.elementAt(index);
                                      return ListTile(
                                        dense: true,
                                        leading: const Icon(
                                          Icons.work_outline,
                                          size: 18,
                                          color: Color(0xFF13B5EA),
                                        ),
                                        title: Text(
                                          option,
                                          style: TextStyle(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                            fontSize: 14,
                                          ),
                                        ),
                                        onTap: () => onSelected(option),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                        ),

                        SizedBox(height: 24),

                        // --- NEW: Upload CV Section ---
                        Text(
                          'Your CV',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 16),
                        InkWell(
                          onTap: _pickAndExtractCV,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color:
                                    (_cvText != null || _cvImageBase64 != null)
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.transparent,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  (_cvText != null || _cvImageBase64 != null)
                                      ? Icons.check_circle
                                      : Icons.upload_file,
                                  color:
                                      (_cvText != null ||
                                          _cvImageBase64 != null)
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.onSurface
                                            .withValues(alpha: 0.54),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _fileName ??
                                        'Tap to select your CV (PDF or Image)',
                                    style: TextStyle(
                                      color:
                                          (_cvText != null ||
                                              _cvImageBase64 != null)
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.onSurface
                                          : Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withValues(alpha: 0.38),
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
                              disabledBackgroundColor: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: _isAnalyzing
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.track_changes,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                            label: Text(
                              _isAnalyzing ? 'Analyzing...' : 'Analyze Match',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 24),
                        Text(
                          'Popular positions:',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.54),
                            fontSize: 13,
                          ),
                        ),
                        SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
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
                      title: "Match Score",
                      icon: Icons.analytics_outlined,
                      color: Colors.blueAccent,
                      content: Text(
                        "${_result!['matchScore'] ?? 0}%",
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    _buildDarkResultCard(
                      title: "Skill Gaps to Fill",
                      icon: Icons.radar,
                      color: Colors.orangeAccent,
                      content: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ..._buildGapWidgets(),
                          if (_getGapSubSkillCount() > 0) ...[
                            SizedBox(height: 16),
                            _buildAddAllButton(),
                          ],
                        ],
                      ),
                    ),
                    if ((_result!['masteredSkills'] as List?)?.isNotEmpty ==
                        true) ...[
                      SizedBox(height: 16),
                      _buildDarkResultCard(
                        title: "Already Mastered",
                        icon: Icons.check_circle,
                        color: Color(0xFF00C896),
                        content: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children:
                              ((_result!['masteredSkills'] as List?) ?? []).map(
                                (s) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Color(
                                        0xFF00C896,
                                      ).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Color(
                                          0xFF00C896,
                                        ).withValues(alpha: 0.5),
                                      ),
                                    ),
                                    child: Text(
                                      s.toString(),
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                        fontSize: 13,
                                      ),
                                    ),
                                  );
                                },
                              ).toList(),
                        ),
                      ),
                    ],
                    // ── CV Feedback: Strengths & Weaknesses ──
                    if (_result!['cvFeedback'] != null) ...[
                      SizedBox(height: 16),
                      _buildCvFeedbackCard(),
                    ],
                    SizedBox(height: 40),
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

  // ─── Gap Helper Methods ────────────────────────────────────

  /// Parse skill gaps safely from AI response
  List<Map<String, dynamic>> _parseGaps() {
    final raw = _result?['skillGaps'];
    if (raw is! List) return [];
    final List<Map<String, dynamic>> parsed = [];
    for (final item in raw) {
      if (item is Map) {
        parsed.add(Map<String, dynamic>.from(item));
      }
    }
    return parsed;
  }

  int _getGapSubSkillCount() {
    int count = 0;
    for (final gap in _parseGaps()) {
      final subs = gap['subSkills'];
      if (subs is List) count += subs.length;
    }
    return count;
  }

  List<Widget> _buildGapWidgets() {
    final gaps = _parseGaps();
    if (gaps.isEmpty) {
      return [
        Text(
          'No skill gaps found — great match!',
          style: TextStyle(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ];
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return gaps.map((gapMap) {
      final String groupName = (gapMap['group'] ?? 'General').toString();
      final int pct = (gapMap['percentage'] is int)
          ? gapMap['percentage']
          : int.tryParse(gapMap['percentage'].toString()) ?? 0;
      final List<String> subSkills = (gapMap['subSkills'] is List)
          ? (gapMap['subSkills'] as List).map((e) => e.toString()).toList()
          : [];
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A1C15) : const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    groupName,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '$pct%',
                  style: TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (pct > 0) ...[
              const SizedBox(height: 8),
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: pct / 100,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.orangeAccent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: subSkills.map((subSkill) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black26 : Colors.white54,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.orangeAccent.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    subSkill,
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.8),
                      fontSize: 13,
                    ),
                  ),
                );
              }).toList(),
            ),
            // ── Per-category Add button ──
            if (subSkills.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 36,
                child: OutlinedButton.icon(
                  onPressed: _isAnalyzing
                      ? null
                      : () => _addCategorySkills(groupName, subSkills),
                  icon: Icon(Icons.add, size: 16, color: Colors.orangeAccent),
                  label: Text(
                    'Add to Checklist',
                    style: TextStyle(fontSize: 12, color: Colors.orangeAccent),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: Colors.orangeAccent.withValues(alpha: 0.5),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }).toList();
  }

  Widget _buildAddAllButton() {
    return Container(
      width: double.infinity,
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          colors: [Color(0xFFFF9800), Color(0xFFE65C00)],
        ),
      ),
      child: ElevatedButton.icon(
        onPressed: _isAnalyzing ? null : _addAllGapSkills,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: const Icon(Icons.playlist_add, color: Colors.white, size: 22),
        label: Text(
          'Add All ${_getGapSubSkillCount()} Skills to Checklist',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Future<void> _addAllGapSkills() async {
    setState(() => _isAnalyzing = true);
    try {
      final session = UserSession.instance;
      int addedCount = 0;
      int skippedCount = 0;
      for (final gap in _parseGaps()) {
        final groupName = (gap['group'] ?? 'General').toString();
        final subSkills = (gap['subSkills'] is List)
            ? (gap['subSkills'] as List).map((e) => e.toString()).toList()
            : <String>[];
        for (final subSkill in subSkills) {
          try {
            final res = await ApiService.instance.createSkillWithCategory(
              userId: session.userId,
              name: subSkill,
              category: groupName,
              isChecked: false,
              token: session.token,
            );
            if (res['alreadyExisted'] == true) {
              skippedCount++;
            } else {
              addedCount++;
            }
          } catch (_) {
            skippedCount++;
          }
        }
      }
      if (mounted) {
        final msg = skippedCount > 0
            ? '$addedCount new skills added ($skippedCount already existed)'
            : '$addedCount skills added to your checklist!';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.green),
        );
      }
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
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  Future<void> _addCategorySkills(
    String category,
    List<String> subSkills,
  ) async {
    setState(() => _isAnalyzing = true);
    try {
      final session = UserSession.instance;
      int addedCount = 0;
      int skippedCount = 0;
      for (final subSkill in subSkills) {
        try {
          final res = await ApiService.instance.createSkillWithCategory(
            userId: session.userId,
            name: subSkill,
            category: category,
            isChecked: false,
            token: session.token,
          );
          if (res['alreadyExisted'] == true) {
            skippedCount++;
          } else {
            addedCount++;
          }
        } catch (_) {
          skippedCount++;
        }
      }
      if (mounted) {
        final msg = skippedCount > 0
            ? '$addedCount new skills added ($skippedCount already existed)'
            : '$addedCount skills added from "$category"!';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.green),
        );
      }
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
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  Widget _buildChip(String label) {
    return GestureDetector(
      onTap: () => setState(() => _jobController.text = label),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Theme.of(context).dividerColor, width: 0.5),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.7),
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildDarkResultCard({
    required String title,
    required IconData icon,
    required Color color,
    required Widget content,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: Theme.of(context).brightness == Brightness.light
            ? [BoxShadow(color: Colors.black12, blurRadius: 10)]
            : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 22),
              SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          content,
        ],
      ),
    );
  }

  Widget _buildCvFeedbackCard() {
    final feedback = _result!['cvFeedback'];
    if (feedback is! Map) return const SizedBox.shrink();
    final strengths =
        (feedback['strengths'] as List?)?.map((e) => e.toString()).toList() ??
        [];
    final weaknesses =
        (feedback['weaknesses'] as List?)?.map((e) => e.toString()).toList() ??
        [];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark
            ? []
            : [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.rate_review, color: Color(0xFF13B5EA), size: 22),
              SizedBox(width: 12),
              Text(
                'CV Feedback',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF13B5EA),
                  fontSize: 16,
                ),
              ),
            ],
          ),
          if (strengths.isNotEmpty) ...[
            SizedBox(height: 16),
            Row(
              children: [
                SizedBox(width: 8),
                Text(
                  'Strengths',
                  style: TextStyle(
                    color: Color(0xFF00C896),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            ...strengths.map(
              (s) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      color: Color(0xFF00C896),
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        s,
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.8),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (weaknesses.isNotEmpty) ...[
            SizedBox(height: 16),
            Row(
              children: [
                SizedBox(width: 8),
                Text(
                  'Needs Improvement',
                  style: TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            ...weaknesses.map(
              (w) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orangeAccent,
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        w,
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.8),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
