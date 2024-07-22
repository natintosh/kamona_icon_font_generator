import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:dart_style/dart_style.dart';
import 'package:icon_font_generator/src/cli/arguments.dart';
import 'package:icon_font_generator/src/cli/options.dart';
import 'package:icon_font_generator/src/common/api.dart';
import 'package:icon_font_generator/src/otf/io.dart';
import 'package:icon_font_generator/src/utils/logger.dart';
import 'package:path/path.dart' as p;
import 'package:recase/recase.dart';
import 'package:yaml/yaml.dart';

final _argParser = ArgParser(allowTrailingOptions: true);
final formatter = DartFormatter(
  pageWidth: 80,
  fixes: StyleFix.all,
);

void main(List<String> args) {
  defineOptions(_argParser);

  late final CliArguments parsedArgs;

  try {
    parsedArgs = parseArgsAndConfig(_argParser, args);
  } on CliArgumentException catch (e) {
    _usageError(e.message);
  } on CliHelpException {
    _printHelp();
  } on YamlException catch (e) {
    logger.e(e.toString());
    exit(66);
  }

  try {
    _run(parsedArgs);
  } on Object catch (e) {
    logger.e(e.toString());
    exit(65);
  }
}

void _run(CliArguments parsedArgs) {
  final stopwatch = Stopwatch()
    ..start();

  final isRecursive = parsedArgs.recursive ?? kDefaultRecursive;
  final isVerbose = parsedArgs.verbose ?? kDefaultVerbose;

  if (isVerbose) {
    logger.setFilterLevel(Level.trace);
  }

  final hasClassFile = parsedArgs.classFile != null;
  if (hasClassFile && !parsedArgs.classFile!.existsSync()) {
    parsedArgs.classFile!.createSync(recursive: true);
  } else if (hasClassFile) {
    logger.t(
        'Output file for a Flutter class already exists (${parsedArgs.classFile!
            .path}) - '
            'overwriting it');
  }

  if (!parsedArgs.fontFile.existsSync()) {
    parsedArgs.fontFile.createSync(recursive: true);
  } else {
    logger.t(
        'Output file for a font file already exists (${parsedArgs.fontFile
            .path}) - '
            'overwriting it');
  }

  final nested = parsedArgs.svgDir.sources.length > 1;
  final Map<String, List<FileSystemEntity>> svgFileMap = {};

  for (final source in parsedArgs.svgDir.sources) {
    final sourceName = p.basenameWithoutExtension(source.path);
    final svgFiles = source
        .listSync(recursive: isRecursive)
        .where((e) => p.extension(e.path).toLowerCase() == '.svg')
        .toList();
    svgFileMap[sourceName] = svgFiles;
  }

  if (svgFileMap.isEmpty) {
    logger.w(
        "The input directory doesn't contain any SVG file (${parsedArgs.svgDir
            .sources.fold('\n', (a, b) => '$a${b.path}\n')}).");
  }

  final symlinkMap = <String, String>{};
  final symlinkMapFile = parsedArgs.symlinkMapFile;
  if (symlinkMapFile != null) {
    final json =
    jsonDecode(symlinkMapFile.readAsStringSync()) as Map<String, dynamic>;

    for (final jsonItem in json.entries) {
      symlinkMap.addAll({
        jsonItem.key: jsonItem.value as String,
      });
    }
  }

  String classString = '';

  for (final entry in svgFileMap.entries) {
    final svgMap = {
      for (final f in entry.value)
        p.basenameWithoutExtension(f.path): File(f.path).readAsStringSync(),
    };

    final fontName = nested
        ? '${parsedArgs.fontName}_${entry.key}'.pascalCase
        : parsedArgs.fontName;

    final otfResult = svgToOtf(
      svgMap: svgMap,
      ignoreShapes: parsedArgs.ignoreShapes,
      normalize: parsedArgs.normalize,
      fontName: fontName,
    );

    final fileName = (p.basenameWithoutExtension(parsedArgs.fontFile.path) + entry.key).snakeCase +
            p.extension(parsedArgs.fontFile.path);

    final fontFilePath = nested
        ? p.join(p.dirname(parsedArgs.fontFile.path), fileName)
        : parsedArgs.fontFile.path;

    writeToFile(fontFilePath, otfResult.font);

    if (parsedArgs.classFile == null) {
      logger.t('No output path for Flutter class was specified - '
          'skipping class generation.');
    } else {
      final fontFileName = p.basename(fontFilePath);

      final className = nested
          ? '${parsedArgs.className}_${entry.key}'.camelCase
          : parsedArgs.className;

      classString += generateFlutterClass(
        glyphList: otfResult.glyphList,
        className: className,
        familyName: otfResult.font.familyName,
        fontFileName: fontFileName,
        namingStrategy: parsedArgs.namingStrategy,
        symlinkMap: symlinkMap,
        package: parsedArgs.fontPackage,
        nested: nested,
      );

      classString += '\n';

      if (parsedArgs.format ?? kDefaultFormat) {
        try {
          logger.t('Formatting Flutter class generation.');
          classString = formatter.format(classString);
        } on Object catch (e) {
          logger.e(e.toString());
        }
      }
    }
  }

  if (nested) {
    classString = '${generateWrapperFlutterClass(
      className: parsedArgs.className,
      subClasses: svgFileMap.keys.toList(),
    )}\n $classString';

    if (parsedArgs.format ?? kDefaultFormat) {
      try {
        logger.t('Formatting Flutter class generation.');
        classString = formatter.format(classString);
      } on Object catch (e) {
        logger.e(e.toString());
      }
    }
  }

  parsedArgs.classFile!.writeAsStringSync(classString);

  logger.i('Generated in ${stopwatch.elapsedMilliseconds}ms');
}

void _printHelp() {
  _printUsage();
  exit(exitCode);
}

void _usageError(String error) {
  _printUsage(error);
  exit(64);
}

void _printUsage([String? error]) {
  final message = error ?? _kAbout;

  stdout.write('''
$message

$_kUsage
${_argParser.usage}
''');
  exit(64);
}

const _kAbout =
    'Converts .svg icons to an OpenType font and generates Flutter-compatible class.';

const _kUsage = '''
Usage:   icon_font_generator <input-svg-dir> <output-font-file> [options]

Example: icon_font_generator assets/svg/ fonts/my_icons_font.otf --output-class-file=lib/my_icons.dart

Converts every .svg file from <input-svg-dir> directory to an OpenType font and writes it to <output-font-file> file.
If "--output-class-file" option is specified, Flutter-compatible class that contains identifiers for the icons is generated.
''';
