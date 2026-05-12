import 'dart:io';

void main() {
  bool hasErrors = true;
  while (hasErrors) {
    print('Running flutter analyze...');
    final result = Process.runSync('flutter', ['analyze', '--no-fatal-infos', '--no-fatal-warnings'], runInShell: true);
    final output = result.stdout.toString() + result.stderr.toString();
    
    final lines = output.split('\n');
    Map<String, List<int>> fixes = {};
    hasErrors = false;

    for (var line in lines) {
      if (!line.contains("Methods can't be invoked in constant expressions")) continue;
      hasErrors = true;
      final parts = line.split(' - ');
      final fileInfo = parts.last.replaceAll(r'\', '/').split(':');
      if (fileInfo.length >= 2) {
        final file = fileInfo[0].trim();
        final lineNum = int.parse(fileInfo[1]);
        fixes.putIfAbsent(file, () => []).add(lineNum);
      }
    }

    if (!hasErrors) {
      print('Done!');
      break;
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
            } else if (idx - 3 >= 0 && contentLines[idx - 3].contains('const ')) {
               contentLines[idx - 3] = contentLines[idx - 3].replaceFirst('const ', '');
            }
          }
        }
      }
      file.writeAsStringSync(contentLines.join('\n'));
    }
  }
}
