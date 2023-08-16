import 'package:recase/recase.dart';

import '../common/constant.dart';
import '../common/generic_glyph.dart';
import '../common/naming_strategy.dart';
import '../otf/defaults.dart';

const _kUnnamedIconName = 'unnamed';
const _kDefaultIndent = 2;
const _kDefaultClassName = 'UiIcons';
const _kDefaultFontFileName = 'icon_font_generator_icons.otf';
const _kDefaultNamingStrategy = NamingStrategy.camel;

/// Removes any characters that are not valid for variable name.
///
/// Returns a new string.
String _getVarName(String string) {
  final replaced = string.replaceAll(RegExp(r'[^a-zA-Z0-9_\-$]'), '');
  return RegExp(r'^[a-zA-Z$].*').firstMatch(replaced)?.group(0) ?? '';
}

String _fixNamingStrategy(String string, NamingStrategy namingStrategy) {
  switch (namingStrategy) {
    case NamingStrategy.camel:
      return string.camelCase;
    case NamingStrategy.snake:
      return string.snakeCase;
  }
}

/// A helper for generating Flutter-compatible class with IconData objects for each icon.
class FlutterClassGenerator {
  /// * [glyphList] is a list of non-default glyphs.
  /// * [className] is generated class' name (preferably, in PascalCase).
  /// * [familyName] is font's family name to use in IconData.
  /// * [package] is the name of a font package. Used to provide a font through package dependency.
  /// * [fontFileName] is font file's name. Used in generated docs for class.
  /// * [indent] is a number of spaces in leading indentation for class' members. Defaults to 2.
  FlutterClassGenerator(
    this.glyphList, {
    String? className,
    String? familyName,
    String? fontFileName,
    int? indent,
    NamingStrategy? namingStrategy,
    String? package,
  })  : _className = _getVarName(className ?? _kDefaultClassName),
        _familyName = familyName ?? kDefaultFontFamily,
        _fontFileName = fontFileName ?? _kDefaultFontFileName,
        _indent = ' ' * (indent ?? _kDefaultIndent),
        _namingStrategy = namingStrategy ?? _kDefaultNamingStrategy,
        _package = package?.isEmpty ?? true ? null : package,
        _iconVarNames = _generateVariableNames(
          glyphList,
          namingStrategy ?? _kDefaultNamingStrategy,
        );

  final List<GenericGlyph> glyphList;
  final String _className;
  final String _familyName;
  final String _fontFileName;
  final String _indent;
  final NamingStrategy _namingStrategy;
  final String? _package;
  final List<String> _iconVarNames;

  static List<String> _generateVariableNames(
    List<GenericGlyph> glyphList,
    NamingStrategy namingStrategy,
  ) {
    final iconNameSet = <String>{};

    return glyphList.map((g) {
      final baseName = _fixNamingStrategy(
        _getVarName(g.metadata.name!),
        namingStrategy,
      );
      final usingDefaultName = baseName.isEmpty;

      var variableName = usingDefaultName ? _kUnnamedIconName : baseName;

      // Handling same names by adding numeration to them
      if (iconNameSet.contains(variableName)) {
        // If name already contains numeration, then splitting it
        final countMatch = RegExp(r'^(.*)_([0-9]+)$').firstMatch(variableName);

        var variableNameCount = 1;
        var variableWithoutCount = variableName;

        if (countMatch != null) {
          variableNameCount = int.parse(countMatch.group(2)!);
          variableWithoutCount = countMatch.group(1)!;
        }

        String variableNameWithCount;

        do {
          variableNameWithCount =
              '${variableWithoutCount}_${++variableNameCount}';
        } while (iconNameSet.contains(variableNameWithCount));

        variableName = variableNameWithCount;
      }

      iconNameSet.add(variableName);

      return variableName;
    }).toList();
  }

  bool get _hasPackage => _package != null;

  String get _fontFamilyConst =>
      "static const iconFontFamily = '$_familyName';";

  String get _fontPackageConst => "static const iconFontPackage = '$_package';";

  List<String> _generateIconConst(int index) {
    final glyphMeta = glyphList[index].metadata;

    final charCode = glyphMeta.charCode!;
    final iconName = _fixNamingStrategy(glyphMeta.name!, _namingStrategy);

    final varName = _iconVarNames[index];
    final hexCode = charCode.toRadixString(16);

    final posParamList = [
      'fontFamily: iconFontFamily',
      if (_hasPackage) 'fontPackage: iconFontPackage'
    ];

    final posParamString = posParamList.join(', ');

    return [
      '',
      '/// Font icon named "__${iconName}__"',
      if (glyphMeta.preview != null) ...[
        '///',
        "/// <image width='32px' src='data:image/svg+xml;base64,${glyphMeta.preview}'>",
      ],
      'static const $varName = IconData(0x$hexCode, $posParamString);'
    ];
  }

  List<String> _generateAllIconsMap() {
    return [
      'static const all = {',
      for (var i = 0; i < glyphList.length; i++)
        () {
          final iconName = _fixNamingStrategy(
            glyphList[i].metadata.name!,
            _namingStrategy,
          );
          return "$_indent'$iconName': $iconName,";
        }.call(),
      '};'
    ];
  }

  /// Generates content for a class' file.
  String generate() {
    final classContent = [
      'const $_className._();',
      '',
      _fontFamilyConst,
      if (_hasPackage) _fontPackageConst,
      for (var i = 0; i < glyphList.length; i++) ..._generateIconConst(i),
      '',
      ..._generateAllIconsMap(),
    ];

    final classContentString =
        classContent.map((e) => e.isEmpty ? '' : '$_indent$e').join('\n');

    return '''// Generated code: do not hand-edit.

// Generated using $kVendorName.
// Copyright © ${DateTime.now().year} $kVendorName ($kVendorUrl).

import 'package:flutter/widgets.dart';

/// Identifiers for the icons.
///
/// Use with the [Icon] class to show specific icons.
///
/// Icons are identified by their name as listed below.
///
/// To use this class, make sure you declare the font in your
/// project's `pubspec.yaml` file in the `fonts` section. This ensures that
/// the "$_familyName" font is included in your application. This font is used to
/// display the icons. For example:
/// 
/// ```yaml
/// flutter:
///   fonts:
///     - family: $_familyName
///       fonts:
///         - asset: fonts/$_fontFileName
/// ```
class $_className {
$classContentString
}
''';
  }
}
