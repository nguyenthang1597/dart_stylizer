import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

const defaultMemberOrdering = <String>[
  'public-constructor',
  'named-constructors',
  'public-static-variables',
  'public-instance-variables',
  'public-override-variables',
  'private-static-variables',
  'private-instance-variables',
  'public-override-methods',
  'public-other-methods',
  'private-other-methods',
  'build-method',
];

class StylizerConfig {
  const StylizerConfig({
    this.groupAndSortGetterMethods = false,
    this.groupAndSortVariableTypes = false,
    this.memberOrdering = defaultMemberOrdering,
    this.processEnumsLikeClasses = false,
    this.sortClassesWithinFile = false,
    this.sortOtherMethods = false,
  });

  factory StylizerConfig.fromJson(
    Map<String, Object?> json, {
    StylizerConfig? base,
  }) {
    final defaults = base ?? const StylizerConfig();
    const options = <String>{
      'groupAndSortGetterMethods',
      'groupAndSortVariableTypes',
      'memberOrdering',
      'processEnumsLikeClasses',
      'sortClassesWithinFile',
      'sortOtherMethods',
    };
    final unknownOptions = json.keys.where((key) => !options.contains(key));
    if (unknownOptions.isNotEmpty) {
      throw FormatException(
        'Unknown configuration option: ${unknownOptions.join(', ')}',
      );
    }

    const known = <String>{
      'public-constructor',
      'named-constructors',
      'public-static-variables',
      'public-instance-variables',
      'public-override-variables',
      'private-static-variables',
      'private-instance-variables',
      'public-override-methods',
      'public-other-methods',
      'private-other-methods',
      'build-method',
    };
    final ordering = json['memberOrdering'];
    if (json.containsKey('memberOrdering') && ordering is! List) {
      throw const FormatException('"memberOrdering" must be an array.');
    }
    final members = !json.containsKey('memberOrdering')
        ? defaults.memberOrdering
        : (ordering as List).map((e) {
            if (e is! String || !known.contains(e)) {
              throw FormatException('Unknown member ordering entry: $e');
            }
            return e;
          }).toList(growable: false);
    if (members.toSet().length != members.length) {
      throw const FormatException(
          '"memberOrdering" cannot contain duplicates.');
    }

    bool boolean(String key, bool fallback) {
      if (!json.containsKey(key)) return fallback;
      final value = json[key];
      if (value is! bool) throw FormatException('"$key" must be a boolean.');
      return value;
    }

    return StylizerConfig(
      groupAndSortGetterMethods: boolean(
        'groupAndSortGetterMethods',
        defaults.groupAndSortGetterMethods,
      ),
      groupAndSortVariableTypes: boolean(
        'groupAndSortVariableTypes',
        defaults.groupAndSortVariableTypes,
      ),
      memberOrdering: members,
      processEnumsLikeClasses: boolean(
        'processEnumsLikeClasses',
        defaults.processEnumsLikeClasses,
      ),
      sortClassesWithinFile: boolean(
        'sortClassesWithinFile',
        defaults.sortClassesWithinFile,
      ),
      sortOtherMethods: boolean(
        'sortOtherMethods',
        defaults.sortOtherMethods,
      ),
    );
  }
  factory StylizerConfig.load([String? path]) =>
      StylizerConfig.loadWithSources(explicitPath: path);

  factory StylizerConfig.loadWithSources({
    String? explicitPath,
    Directory? projectDirectory,
    String? globalConfigPath,
  }) {
    if (explicitPath != null && !File(explicitPath).existsSync()) {
      throw FileSystemException(
        'Configuration file does not exist',
        File(explicitPath).path,
      );
    }

    var config = const StylizerConfig();
    final globalPath = globalConfigPath ?? _defaultGlobalConfigPath();
    if (globalPath != null && File(globalPath).existsSync()) {
      config = _loadConfigFile(File(globalPath), config);
    }

    final projectConfig =
        _findProjectConfig(projectDirectory ?? Directory.current);
    if (projectConfig != null) {
      config = _loadConfigFile(projectConfig, config);
    }

    if (explicitPath != null) {
      config = _loadConfigFile(File(explicitPath), config);
    }
    return config;
  }

  final bool groupAndSortGetterMethods;
  final bool groupAndSortVariableTypes;
  final List<String> memberOrdering;
  final bool processEnumsLikeClasses;
  final bool sortClassesWithinFile;
  final bool sortOtherMethods;
}

StylizerConfig _loadConfigFile(File file, StylizerConfig base) {
  final decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! Map<String, Object?>) {
    throw const FormatException('Configuration root must be a JSON object.');
  }
  return StylizerConfig.fromJson(decoded, base: base);
}

File? _findProjectConfig(Directory directory) {
  var current = directory.absolute;
  while (true) {
    final file = File(p.join(current.path, '.dart_stylizer.json'));
    if (file.existsSync()) return file;

    final parent = current.parent;
    if (parent.path == current.path) return null;
    current = parent;
  }
}

String? _defaultGlobalConfigPath() {
  final environment = Platform.environment;
  String? configDirectory;
  if (Platform.isWindows) {
    configDirectory = environment['APPDATA'];
    if (configDirectory == null || configDirectory.isEmpty) {
      final home = environment['USERPROFILE'] ?? environment['HOME'];
      if (home != null && home.isNotEmpty) {
        configDirectory = p.join(home, 'AppData', 'Roaming');
      }
    }
  } else {
    final xdgConfigHome = environment['XDG_CONFIG_HOME'];
    if (xdgConfigHome != null &&
        xdgConfigHome.isNotEmpty &&
        p.isAbsolute(xdgConfigHome)) {
      configDirectory = xdgConfigHome;
    } else {
      final home = environment['HOME'];
      if (home != null && home.isNotEmpty) {
        configDirectory = p.join(home, '.config');
      }
    }
  }

  if (configDirectory == null || configDirectory.isEmpty) return null;
  return p.join(configDirectory, 'dart_stylizer', 'config.json');
}
