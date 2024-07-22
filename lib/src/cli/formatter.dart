import 'dart:convert';
import 'dart:io';

import 'package:yaml/yaml.dart';

import '../common/source_directories.dart';
import 'arguments.dart';


typedef CliArgumentFormatter = Object Function(String arg);

const _kArgumentFormatters = <CliArgument, CliArgumentFormatter>{
  CliArgument.svgDir: SourceDirectories.new,
  CliArgument.fontFile: File.new,
  CliArgument.classFile: File.new,
  CliArgument.symlinkMapFile: File.new,
  CliArgument.configFile: File.new,
};

/// Formats arguments.
Map<CliArgument, Object?> formatArguments(Map<CliArgument, Object?> args) {
  return args.map<CliArgument, Object?>((k, v) {
    final formatter = _kArgumentFormatters[k];

    if (formatter == null || v == null) {
      return MapEntry<CliArgument, Object?>(k, v);
    }

    final input = switch (v) {
      YamlList() => v.toList(),
      _ => v,
    };

    return MapEntry<CliArgument, Object?>(k, formatter(input.toString()));
  });
}
