import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:args/args.dart';
import 'package:dart_style/dart_style.dart';
import 'package:glob/glob.dart';
import 'package:glob/list_local_fs.dart';
import 'package:path/path.dart' as p;

import 'config.dart';
import 'organizer.dart';

Future<void> runCli(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('config', abbr: 'c', help: 'Path to a JSON configuration file.')
    ..addFlag('write',
        abbr: 'w',
        negatable: false,
        help: 'Write organized source back to the input files.')
    ..addFlag('check',
        negatable: false, help: 'Exit with code 1 if any file would change.')
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show usage.');
  late ArgResults options;
  try {
    options = parser.parse(arguments);
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    stderr.writeln(parser.usage);
    exitCode = 2;
    return;
  }
  if (options['help'] as bool || options.rest.isEmpty) {
    stdout.writeln('Dart Stylizer - organize class members\n');
    stdout
        .writeln('Usage: dart run dart_stylizer [options] <file-or-glob>...\n');
    stdout.writeln(parser.usage);
    return;
  }
  if (options['write'] as bool && options['check'] as bool) {
    stderr.writeln('--write and --check cannot be used together.');
    exitCode = 2;
    return;
  }

  try {
    final config = StylizerConfig.load(options['config'] as String?);
    final organizer = DartOrganizer(config);
    final formatter = DartFormatter(
      languageVersion: DartFormatter.latestLanguageVersion,
    );
    final paths = <String>{};
    final unmatchedPatterns = <String>[];
    for (final pattern in options.rest) {
      final matches = await Glob(pattern).list().toList();
      if (matches.isEmpty) {
        unmatchedPatterns.add(pattern);
        continue;
      }
      for (final entity in matches) {
        if (entity is File && p.extension(entity.path) == '.dart') {
          paths.add(p.normalize(entity.path));
        }
      }
    }
    if (unmatchedPatterns.isNotEmpty) {
      throw FormatException(
        'No paths matched: ${unmatchedPatterns.join(', ')}',
      );
    }
    if (paths.isEmpty) {
      stderr.writeln('No Dart files matched the supplied paths.');
      exitCode = 1;
      return;
    }

    final changedFiles = <String, String>{};
    for (final path in paths.toList()..sort()) {
      final original = await File(path).readAsString();
      final parsed = parseString(content: original, throwIfDiagnostics: false);
      if (parsed.errors.isNotEmpty) {
        final error = parsed.errors.first;
        final line = parsed.lineInfo.getLocation(error.offset).lineNumber;
        throw FormatException(
          'Could not parse $path:$line: ${error.message}',
        );
      }
      final organized = organizer.organizeParsed(original, parsed.unit);
      final formatted = formatter.format(organized, uri: path);
      if (formatted != original) changedFiles[path] = formatted;
    }

    final changedPaths = changedFiles.keys.toList()..sort();
    if (options['write'] as bool) {
      for (final path in changedPaths) {
        await File(path).writeAsString(changedFiles[path]!);
        stdout.writeln('Organized $path');
      }
    } else if (options['check'] as bool) {
      for (final path in changedPaths) {
        stdout.writeln('Needs organization: $path');
      }
      if (changedPaths.isNotEmpty) exitCode = 1;
    } else {
      for (final path in changedPaths) {
        stdout.writeln('--- $path');
        stdout.write(changedFiles[path]!);
      }
    }
  } on Object catch (error) {
    stderr.writeln('dart_stylizer: $error');
    exitCode = 2;
  }
}
