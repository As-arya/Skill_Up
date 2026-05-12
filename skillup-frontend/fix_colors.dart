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
    
    content = content.replaceAll('const Color(0xFF0B1120)', 'Theme.of(context).scaffoldBackgroundColor');
    content = content.replaceAll('Color(0xFF0B1120)', 'Theme.of(context).scaffoldBackgroundColor');
    content = content.replaceAll('const Color(0xFF151C2C)', 'Theme.of(context).colorScheme.surface');
    content = content.replaceAll('Color(0xFF151C2C)', 'Theme.of(context).colorScheme.surface');
    content = content.replaceAll('const Color(0xFF1C2438)', 'Theme.of(context).dividerColor');
    content = content.replaceAll('Color(0xFF1C2438)', 'Theme.of(context).dividerColor');
    content = content.replaceAll('const Color(0xFF222B40)', 'Theme.of(context).dividerColor');
    content = content.replaceAll('Color(0xFF222B40)', 'Theme.of(context).dividerColor');
    
    content = content.replaceAll('color: Colors.white,', 'color: Theme.of(context).colorScheme.onSurface,');
    content = content.replaceAll('color: Colors.white)', 'color: Theme.of(context).colorScheme.onSurface)');
    
    content = content.replaceAll('color: Colors.white54', 'color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54)');
    content = content.replaceAll('color: Colors.white70', 'color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)');
    content = content.replaceAll('color: Colors.white38', 'color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38)');
    
    // Fix invalid const usages
    content = content.replaceAll('const TextStyle(color: Theme.of(context)', 'TextStyle(color: Theme.of(context)');
    content = content.replaceAll('const TextStyle(\n                                        color: Theme.of(context)', 'TextStyle(\n                                        color: Theme.of(context)');
    content = content.replaceAll('const TextStyle(\n                                  color: Theme.of(context)', 'TextStyle(\n                                  color: Theme.of(context)');
    content = content.replaceAll('const TextStyle(\n                              color: Theme.of(context)', 'TextStyle(\n                              color: Theme.of(context)');
    content = content.replaceAll('const Icon(Icons.wifi_off, color: Theme.of(context)', 'Icon(Icons.wifi_off, color: Theme.of(context)');
    content = content.replaceAll('const Text(\'Cancel\', style: TextStyle(color: Theme.of(context)', 'Text(\'Cancel\', style: TextStyle(color: Theme.of(context)');
    content = content.replaceAll('const Icon(Icons.warning_amber_rounded, color: Theme.of(context)', 'Icon(Icons.warning_amber_rounded, color: Theme.of(context)');

    file.writeAsStringSync(content);
  }
}

