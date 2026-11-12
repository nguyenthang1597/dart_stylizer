import 'dart:convert';
import 'dart:io';

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

  factory StylizerConfig.fromJson(Map<String, Object?> json) {
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
    final members = ordering == null
        ? defaultMemberOrdering
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
      groupAndSortGetterMethods: boolean('groupAndSortGetterMethods', false),
      groupAndSortVariableTypes: boolean('groupAndSortVariableTypes', false),
      memberOrdering: members,
      processEnumsLikeClasses: boolean('processEnumsLikeClasses', false),
      sortClassesWithinFile: boolean('sortClassesWithinFile', false),
      sortOtherMethods: boolean('sortOtherMethods', false),
    );
  }
  factory StylizerConfig.load([String? path]) {
    final file = File(path ?? '.dart_stylizer.json');
    if (!file.existsSync()) {
      if (path == null) return const StylizerConfig();
      throw FileSystemException('Configuration file does not exist', file.path);
    }
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('Configuration root must be a JSON object.');
    }
    return StylizerConfig.fromJson(decoded);
  }

  final bool groupAndSortGetterMethods;
  final bool groupAndSortVariableTypes;
  final List<String> memberOrdering;
  final bool processEnumsLikeClasses;
  final bool sortClassesWithinFile;
  final bool sortOtherMethods;
}
