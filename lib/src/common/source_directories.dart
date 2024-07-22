import 'dart:convert';
import 'dart:io';

class SourceDirectories {
  SourceDirectories(String paths)
      : sources = paths
            .substring(1, paths.length - 1) // Remove the square brackets
            .split(', ') // Split the string by comma and space
            .map((item) => Directory(
                item.trim())) // Remove any surrounding whitespace from items
            .toList();

  final List<Directory> sources;
}
