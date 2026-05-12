import 'dart:io';

void main() {
  final errors = '''
  error - Methods can't be invoked in constant expressions - lib/cv_checker_page.dart:184:57
  error - Methods can't be invoked in constant expressions - lib/cv_checker_page.dart:186:130
  error - Methods can't be invoked in constant expressions - lib/cv_checker_page.dart:192:61
  error - Methods can't be invoked in constant expressions - lib/cv_checker_page.dart:251:38
  error - Methods can't be invoked in constant expressions - lib/cv_checker_page.dart:258:51
  error - Methods can't be invoked in constant expressions - lib/cv_checker_page.dart:333:40
  error - Methods can't be invoked in constant expressions - lib/cv_checker_page.dart:341:51
  error - Methods can't be invoked in constant expressions - lib/cv_checker_page.dart:352:43
  error - Methods can't be invoked in constant expressions - lib/cv_checker_page.dart:457:34
  error - Methods can't be invoked in constant expressions - lib/home_page.dart:475:46
  error - Methods can't be invoked in constant expressions - lib/portfolio_checker_page.dart:104:38
  error - Methods can't be invoked in constant expressions - lib/portfolio_checker_page.dart:111:51
  error - Methods can't be invoked in constant expressions - lib/portfolio_checker_page.dart:154:40
  error - Methods can't be invoked in constant expressions - lib/portfolio_checker_page.dart:162:51
  error - Methods can't be invoked in constant expressions - lib/portfolio_checker_page.dart:188:65
  error - Methods can't be invoked in constant expressions - lib/portfolio_checker_page.dart:190:130
  error - Methods can't be invoked in constant expressions - lib/portfolio_checker_page.dart:196:61
  error - Methods can't be invoked in constant expressions - lib/portfolio_checker_page.dart:205:43
  error - Methods can't be invoked in constant expressions - lib/portfolio_checker_page.dart:288:34
  error - Methods can't be invoked in constant expressions - lib/projects_page.dart:164:38
  error - Methods can't be invoked in constant expressions - lib/projects_page.dart:171:51
  error - Methods can't be invoked in constant expressions - lib/projects_page.dart:193:61
  error - Methods can't be invoked in constant expressions - lib/projects_page.dart:195:130
  error - Methods can't be invoked in constant expressions - lib/projects_page.dart:201:61
  error - Methods can't be invoked in constant expressions - lib/projects_page.dart:227:42
  error - Methods can't be invoked in constant expressions - lib/projects_page.dart:250:51
  error - Methods can't be invoked in constant expressions - lib/projects_page.dart:266:50
  error - Methods can't be invoked in constant expressions - lib/projects_page.dart:272:51
  error - Methods can't be invoked in constant expressions - lib/projects_page.dart:362:34
  error - Methods can't be invoked in constant expressions - lib/skill_matching_page.dart:148:38
  error - Methods can't be invoked in constant expressions - lib/skill_matching_page.dart:155:51
  error - Methods can't be invoked in constant expressions - lib/skill_matching_page.dart:227:48
  error - Methods can't be invoked in constant expressions - lib/skill_matching_page.dart:249:50
  error - Methods can't be invoked in constant expressions - lib/skill_matching_page.dart:270:52
  error - Methods can't be invoked in constant expressions - lib/skill_matching_page.dart:277:53
  error - Methods can't be invoked in constant expressions - lib/skill_matching_page.dart:377:127
  error - Methods can't be invoked in constant expressions - lib/skill_matching_page.dart:378:72
  error - Methods can't be invoked in constant expressions - lib/skill_page.dart:98:38
  error - Methods can't be invoked in constant expressions - lib/skill_page.dart:105:51
  error - Methods can't be invoked in constant expressions - lib/skill_page.dart:125:48
  error - Methods can't be invoked in constant expressions - lib/skill_page.dart:268:30
  error - Methods can't be invoked in constant expressions - lib/skill_page.dart:276:41
  error - Methods can't be invoked in constant expressions - lib/skill_page.dart:379:34
  ''';

  final lines = errors.split('\n');
  Map<String, List<int>> fixes = {};

  for (var line in lines) {
    if (!line.contains("Methods can't be invoked")) continue;
    final parts = line.split(' - ');
    final fileInfo = parts.last.replaceAll(r'\', '/').split(':');
    if (fileInfo.length >= 2) {
      final file = fileInfo[0].trim();
      final lineNum = int.parse(fileInfo[1]);
      fixes.putIfAbsent(file, () => []).add(lineNum);
    }
  }

  for (var entry in fixes.entries) {
    final file = File(entry.key);
    if (!file.existsSync()) continue;
    
    final contentLines = file.readAsLinesSync();
    for (var lineNum in entry.value) {
      final idx = lineNum - 1;
      if (idx >= 0 && idx < contentLines.length) {
        if (contentLines[idx].contains('const ')) {
          contentLines[idx] = contentLines[idx].replaceFirst('const ', '');
        } else {
          if (idx - 1 >= 0 && contentLines[idx - 1].contains('const ')) {
             contentLines[idx - 1] = contentLines[idx - 1].replaceFirst('const ', '');
          } else if (idx - 2 >= 0 && contentLines[idx - 2].contains('const ')) {
             contentLines[idx - 2] = contentLines[idx - 2].replaceFirst('const ', '');
          }
        }
      }
    }
    file.writeAsStringSync(contentLines.join('\n'));
  }
}
