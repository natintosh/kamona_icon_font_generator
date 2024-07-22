import 'package:recase/recase.dart';

import '../otf.dart';
import '../svg.dart';
import '../utils/flutter_class_gen.dart';
import '../utils/logger.dart';
import 'generic_glyph.dart';
import 'naming_strategy.dart';

/// Result of svg-to-otf conversion.
///
/// Contains list of generated glyphs and created font.
class SvgToOtfResult {
  SvgToOtfResult._(this.glyphList, this.font);

  final List<GenericGlyph> glyphList;
  final OpenTypeFont font;
}

/// Converts SVG icons to OTF font.
///
/// * [svgMap] contains name (key) to data (value) SVG mapping. Required.
/// * If [ignoreShapes] is set to false, shapes (circle, rect, etc.) are converted into paths.
/// Defaults to true.
/// NOTE: Attributes like "fill" or "stroke" are ignored,
/// which means only shape's outline will be used.
/// * If [normalize] is set to true,
/// glyphs are resized and centered to fit in coordinates grid (unitsPerEm).
/// Defaults to true.
/// * [fontName] is a name for a generated font.
///
/// Returns an instance of [SvgToOtfResult] class containing glyphs and a font.
SvgToOtfResult svgToOtf({
  required Map<String, String> svgMap,
  bool? ignoreShapes,
  bool? normalize,
  String? fontName,
}) {
  normalize ??= true;

  final svgList = [
    for (final e in svgMap.entries)
      Svg.parse(e.key, e.value, ignoreShapes: ignoreShapes)
  ];

  if (!normalize) {
    for (var i = 1; i < svgList.length; i++) {
      if (svgList[i - 1].viewBox.height != svgList[i].viewBox.height) {
        logger.logOnce(
            Level.warning,
            'Some SVG files contain different view box height, '
            'while normalization option is disabled. '
            'This is not recommended.');
        break;
      }
    }
  }

  final glyphList = svgList.map(GenericGlyph.fromSvg).toList();

  final font = OpenTypeFont.createFromGlyphs(
    glyphList: glyphList,
    fontName: fontName,
    normalize: normalize,
    useOpenType: true,
    usePostV2: true,
  );

  return SvgToOtfResult._(glyphList, font);
}

/// Generates a Flutter-compatible class for a list of glyphs.
///
/// * [glyphList] is a list of non-default glyphs.
/// * [className] is generated class' name (preferably, in PascalCase).
/// * [familyName] is font's family name to use in IconData.
/// * [package] is the name of a font package. Used to provide a font through package dependency.
/// * [fontFileName] is font file's name. Used in generated docs for class.
/// * [indent] is a number of spaces in leading indentation for class' members. Defaults to 2.
///
/// Returns content of a class file.
String generateFlutterClass({
  required List<GenericGlyph> glyphList,
  String? className,
  String? familyName,
  String? fontFileName,
  NamingStrategy? namingStrategy,
  Map<String, String>? symlinkMap,
  int? indent,
  String? package,
  bool nested = false,
}) {
  final generator = FlutterClassGenerator(
    glyphList,
    className: className,
    familyName: familyName,
    fontFileName: fontFileName,
    indent: indent,
    namingStrategy: namingStrategy,
    symlinkMap: symlinkMap,
    package: package,
    nested: nested,
  );

  return generator.generate();
}

String generateWrapperFlutterClass({
  String? className,
  List<String> subClasses = const [],
}) {
  return '''
${classHeader()}

abstract final class ${getVarName(className ?? kDefaultClassName)} {
  ${subClasses.map((e) {
    final childClassName = '${className ?? ''}_$e'.camelCase;
    return 'static const ${e.camelCase} = $childClassName._();';
  }).join('\n')}
}
''';
}
