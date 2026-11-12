import 'package:dart_stylizer/dart_stylizer.dart';
import 'package:test/test.dart';

void main() {
  group('DartOrganizer', () {
    test('puts constructors and sorted fields before methods', () {
      const input = '''
class Example {
  void zebra() {}
  int z = 0;
  Example.named();
  static int b = 0;
  Example();
  int a = 0;
  static int aStatic = 0;
  void alpha() {}
}
''';
      final output = const DartOrganizer(StylizerConfig()).organize(input);
      expect(output.indexOf('Example();'),
          lessThan(output.indexOf('Example.named();')));
      expect(output.indexOf('static int aStatic'),
          lessThan(output.indexOf('static int b')));
      expect(
          output.indexOf('int a = 0'), lessThan(output.indexOf('int z = 0')));
      expect(
          output.indexOf('void zebra'), lessThan(output.indexOf('void alpha')));
    });

    test('keeps other methods in original order by default', () {
      const input = '''
class Example {
  void z() {}
  void a() {}
}
''';
      final output = const DartOrganizer(StylizerConfig()).organize(input);
      expect(output.indexOf('void z'), lessThan(output.indexOf('void a')));
    });

    test('keeps private methods in their own group and source order', () {
      const input = '''
class Example {
  void _z() {}
  void publicMethod() {}
  void _a() {}
}
''';
      final output = const DartOrganizer(StylizerConfig()).organize(input);

      expect(output.indexOf('publicMethod'), lessThan(output.indexOf('_z')));
      expect(output.indexOf('_z'), lessThan(output.indexOf('_a')));
    });

    test('sorts other methods when enabled', () {
      const input = '''
class Example {
  void z() {}
  void a() {}
}
''';
      final output = const DartOrganizer(
        StylizerConfig(sortOtherMethods: true),
      ).organize(input);
      expect(output.indexOf('void a'), lessThan(output.indexOf('void z')));
    });

    test('separates non-empty member groups and is idempotent', () {
      const input = '''
class Example {
  int value = 0;
  static const int count = 1;
  void build() {}
  void run() {}
}
''';
      const organizer = DartOrganizer(StylizerConfig());
      final output = organizer.organize(input);

      expect(output, contains('static const int count = 1;\n\n  int value'));
      expect(output, contains('void run() {}\n\n  void build() {}'));
      expect(organizer.organize(output), output);
    });

    test('keeps comments attached while sorting members', () {
      const input = '''
class Example {
  /// Zulu documentation.
  @override
  void zulu() {}
  /// Alpha documentation.
  @override
  void alpha() {}
}
''';
      final output = const DartOrganizer(StylizerConfig()).organize(input);

      expect(
        output.indexOf('Alpha documentation'),
        lessThan(output.indexOf('Zulu documentation')),
      );
      expect(output,
          contains('/// Alpha documentation.\n  @override\n  void alpha()'));
    });

    test('leaves invalid Dart source unchanged', () {
      const input = 'class Example { int value = ; }';
      expect(const DartOrganizer(StylizerConfig()).organize(input), input);
    });

    test('sorts top-level classes without dropping other declarations', () {
      const input = '''
class Zebra {}

int marker = 1;

class Alpha {}
''';
      final output = const DartOrganizer(
        StylizerConfig(sortClassesWithinFile: true),
      ).organize(input);

      expect(output.indexOf('class Alpha'), lessThan(output.indexOf('marker')));
      expect(output.indexOf('marker'), lessThan(output.indexOf('class Zebra')));
      expect(output, contains('int marker = 1;'));
    });

    test('groups and sorts getters when enabled', () {
      const input = '''
class Example {
  void zMethod() {}
  int get zGetter => 1;
  void aMethod() {}
  int get aGetter => 0;
}
''';
      final output = const DartOrganizer(
        StylizerConfig(groupAndSortGetterMethods: true),
      ).organize(input);

      expect(output.indexOf('aGetter'), lessThan(output.indexOf('zGetter')));
      expect(output.indexOf('zGetter'), lessThan(output.indexOf('zMethod')));
      expect(output, contains('zGetter => 1;\n\n  void zMethod'));
      expect(output.indexOf('zMethod'), lessThan(output.indexOf('aMethod')));
    });

    test('groups and sorts fields by type when enabled', () {
      const input = '''
class Example {
  String b = '';
  int z = 0;
  int a = 0;
}
''';
      final output = const DartOrganizer(
        StylizerConfig(groupAndSortVariableTypes: true),
      ).organize(input);

      expect(output.indexOf('int a'), lessThan(output.indexOf('int z')));
      expect(output.indexOf('int z'), lessThan(output.indexOf('String b')));
      expect(output, contains('int z = 0;\n\n  String b ='));
    });

    test('keeps enum constant order while organizing enum members', () {
      const input = '''
enum Example {
  zebra,
  alpha;
  int zValue = 0;
  int aValue = 0;
}
''';
      final output = const DartOrganizer(
        StylizerConfig(processEnumsLikeClasses: true),
      ).organize(input);

      expect(output.indexOf('zebra'), lessThan(output.indexOf('alpha')));
      expect(output.indexOf('aValue'), lessThan(output.indexOf('zValue')));
    });

    test('preserves CRLF line endings', () {
      const input = 'class Example {\r\n  int z = 0;\r\n  int a = 0;\r\n}\r\n';
      final output = const DartOrganizer(StylizerConfig()).organize(input);

      expect(output, contains('int a = 0;\r\n  int z = 0;'));
      expect(output.replaceAll('\r\n', ''), isNot(contains('\n')));
    });
  });
}
