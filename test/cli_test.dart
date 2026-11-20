import 'dart:io';

import 'package:dart_stylizer/dart_stylizer.dart';
import 'package:test/test.dart';

import 'package:dart_stylizer/src/unified_diff.dart';

void main() {
  group('runCli', () {
    late Directory directory;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('dart_stylizer_cli');
      exitCode = 0;
    });

    tearDown(() async {
      exitCode = 0;
      await directory.delete(recursive: true);
    });

    test('preview and check do not write while write mode does', () async {
      final file = File('${directory.path}/example.dart');
      const original = 'class Example {\n  int z=0;\n  int a=0;\n}\n';
      await file.writeAsString(original);

      await runCli(['--check', file.path]);
      expect(exitCode, 1);
      expect(await file.readAsString(), original);

      exitCode = 0;
      await runCli([file.path]);
      expect(await file.readAsString(), original);

      exitCode = 0;
      await runCli(['--write', file.path]);
      expect(exitCode, 0);
      final written = await file.readAsString();
      expect(written, isNot(original));
      expect(written, contains('int a=0;'));
      expect(written, contains('int z=0;'));

      exitCode = 0;
      await runCli(['--check', file.path]);
      expect(exitCode, 0);
    });

    test('parses and formats recent Dart language syntax', () async {
      final file = File('${directory.path}/modern.dart');
      const original = '''
// @dart=3.14
class Example(int value){
  int z=0;
  int a=0;
}
''';
      await file.writeAsString(original);

      await runCli(['--write', '--format', file.path]);

      expect(exitCode, 0);
      final written = await file.readAsString();
      expect(written, contains('// @dart=3.14'));
      expect(written, contains('class Example(int value) {'));
      expect(
        written.indexOf('int a = 0;'),
        lessThan(written.indexOf('int z = 0;')),
      );
    });

    test(
      'preserves unrelated formatting unless --format is requested',
      () async {
        final file = File('${directory.path}/source_preserving.dart');
        const original = '''
void untouched( ){  print("keep"); }

class Example {
  int z=0;
  int a=0;
}
''';
        await file.writeAsString(original);

        await runCli(['--write', file.path]);

        final written = await file.readAsString();
        expect(written, startsWith('void untouched( ){  print("keep"); }'));
        expect(
          written.indexOf('int a=0;'),
          lessThan(written.indexOf('int z=0;')),
        );
      },
    );

    test('diff mode is available in preview and check modes', () async {
      final file = File('${directory.path}/diff.dart');
      const original = '''
class Example {
  int z=0;
  int a=0;
}
''';
      await file.writeAsString(original);

      await runCli(['--diff', file.path]);
      expect(exitCode, 0);
      expect(await file.readAsString(), original);

      await runCli(['--check', '--diff', file.path]);
      expect(exitCode, 1);
      expect(await file.readAsString(), original);
    });

    test('unified diff includes changed lines and nearby context', () {
      final diff = unifiedDiff(
        'example.dart',
        'before();\nvalue = 0;\nafter();\n',
        'before();\nvalue = 1;\nafter();\n',
      );

      expect(diff, contains('--- example.dart\n+++ example.dart'));
      expect(diff, contains('@@ -1,3 +1,3 @@'));
      expect(diff, contains(' before();'));
      expect(diff, contains('-value = 0;'));
      expect(diff, contains('+value = 1;'));
      expect(diff, contains(' after();'));
    });

    test('unified diff marks missing final newlines', () {
      final diff = unifiedDiff('example.dart', 'old', 'new\n');

      expect(diff, contains('-old\n\\ No newline at end of file'));
      expect(diff, contains('+new'));
    });

    test(
      'preserves each file newline style when processing concurrently',
      () async {
        final lfFile = File('${directory.path}/lf.dart');
        final crlfFile = File('${directory.path}/crlf.dart');
        await lfFile.writeAsString(
          'class Example {\n  int z=0;\n  int a=0;\n}\n',
        );
        await crlfFile.writeAsString(
          'class Example {\r\n  int z=0;\r\n  int a=0;\r\n}\r\n',
        );

        await runCli(['--write', lfFile.path, crlfFile.path]);

        final lf = await lfFile.readAsString();
        final crlf = await crlfFile.readAsString();
        expect(lf, isNot(contains('\r')));
        expect(crlf.replaceAll('\r\n', ''), isNot(contains('\n')));
        expect(crlf, contains('int a=0;\r\n'));
      },
    );

    test(
      'does not write any files if a matched Dart file cannot be parsed',
      () async {
        final valid = File('${directory.path}/a.dart');
        final invalid = File('${directory.path}/z.dart');
        const original = 'class Example {\n  int z=0;\n  int a=0;\n}\n';
        await valid.writeAsString(original);
        await invalid.writeAsString('class Broken { int value = ; }');

        await runCli(['--write', valid.path, invalid.path]);

        expect(exitCode, 2);
        expect(await valid.readAsString(), original);
      },
    );
  });
}
