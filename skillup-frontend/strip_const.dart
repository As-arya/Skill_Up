import 'dart:io';

void main() {
  final files = [
    'lib/skill_page.dart',
    'lib/portfolio_checker_page.dart',
    'lib/cv_checker_page.dart',
    'lib/skill_matching_page.dart',
    'lib/projects_page.dart',
    'lib/home_page.dart'
  ];

  for (final filePath in files) {
    final file = File(filePath);
    if (!file.existsSync()) continue;

    String content = file.readAsStringSync();
    
    final targets = [
      'const Text(', 'const TextStyle(', 'const Icon(', 'const Center(', 'const Padding(',
      'const Row(', 'const Column(', 'const SizedBox(', 'const Container(', 'const Expanded(',
      'const Align(', 'const CircleAvatar(', 'const BoxDecoration(', 'const BoxShadow(',
      'const BorderSide(', 'const BorderRadius.circular(', 'const EdgeInsets.all(',
      'const EdgeInsets.symmetric(', 'const EdgeInsets.only(', 'const EdgeInsets.fromLTRB(',
      'const InputDecoration(', 'const OutlineInputBorder(', 'const AlertDialog(', 'const DropdownMenuItem(',
      'const LinearGradient(', 'const TextSpan(', 'const AlwaysStoppedAnimation<Color>('
    ];

    for (var target in targets) {
      content = content.replaceAll(target, target.substring(6));
    }
    
    file.writeAsStringSync(content);
  }
}

