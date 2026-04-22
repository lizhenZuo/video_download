import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/download_models.dart';

typedef ProgressReporter = void Function(double progress);

class VideoDownloadException implements Exception {
  const VideoDownloadException(this.message);

  final String message;

  @override
  String toString() => message;
}

Future<Directory> resolveOutputDirectory({required bool preferShared}) async {
  final directory = await _resolveTubeFetchDirectory(
    preferShared: preferShared,
    createIfMissing: true,
  );

  if (directory == null) {
    throw const FileSystemException('无法定位可用的下载目录。');
  }

  return directory;
}

Future<List<Directory>> resolveCacheDirectories() async {
  final directories = <String, Directory>{};

  for (final preferShared in [true, false]) {
    final directory = await _resolveTubeFetchDirectory(
      preferShared: preferShared,
      createIfMissing: false,
    );

    if (directory != null) {
      directories[directory.path] = directory;
    }
  }

  return directories.values.toList(growable: false);
}

Future<int> measureAppCacheBytes() async {
  final directories = await resolveCacheDirectories();
  var total = 0;

  for (final directory in directories) {
    total += await measureDirectoryBytes(directory);
  }

  return total;
}

Future<int> clearAppCache() async {
  final directories = await resolveCacheDirectories();
  var clearedBytes = 0;

  for (final directory in directories) {
    clearedBytes += await measureDirectoryBytes(directory);
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  return clearedBytes;
}

Future<int> measureDirectoryBytes(Directory directory) async {
  if (!await directory.exists()) {
    return 0;
  }

  var total = 0;
  await for (final entity in directory.list(recursive: true, followLinks: false)) {
    if (entity is! File) {
      continue;
    }

    try {
      total += await entity.length();
    } on FileSystemException {
      continue;
    }
  }

  return total;
}

Future<Directory?> _resolveTubeFetchDirectory({
  required bool preferShared,
  required bool createIfMissing,
}) async {
  Directory? baseDirectory;

  if (preferShared) {
    if (Platform.isAndroid) {
      baseDirectory = await getExternalStorageDirectory();
    } else if (!Platform.isIOS) {
      baseDirectory = await getDownloadsDirectory();
    }
  }

  baseDirectory ??= await getApplicationDocumentsDirectory();

  final directory = Directory('${baseDirectory.path}/TubeFetch');
  if (!await directory.exists()) {
    if (!createIfMissing) {
      return null;
    }

    await directory.create(recursive: true);
  }

  return directory;
}

String buildSafeFileName(String videoTitle, DownloadAsset asset) {
  final safeTitle = sanitizeFileName(videoTitle);
  final safeStem = sanitizeFileName(asset.fileStem);
  final extension = '.${asset.fileExtension}';
  final suffix = '-$safeStem';
  const maxFileNameBytes = 180;
  final reservedBytes = utf8.encode('$suffix$extension').length;
  final titleBudget = maxFileNameBytes - reservedBytes;
  final truncatedTitle = truncateUtf8(
    safeTitle.isEmpty ? asset.source.fallbackFilePrefix : safeTitle,
    titleBudget > 24 ? titleBudget : 24,
  );

  return '$truncatedTitle$suffix$extension';
}

String sanitizeFileName(String input) {
  final cleaned = input
      .replaceAll(RegExp(r'[\\/:*?"<>|]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  return cleaned;
}

String truncateUtf8(String input, int maxBytes) {
  if (utf8.encode(input).length <= maxBytes) {
    return input;
  }

  final buffer = StringBuffer();

  for (final rune in input.runes) {
    final char = String.fromCharCode(rune);
    final candidate = '$buffer$char';
    if (utf8.encode(candidate).length > maxBytes) {
      break;
    }
    buffer.write(char);
  }

  final result = buffer.toString().trim();
  return result.isEmpty ? 'media' : result;
}

String trimDescription(String description) {
  final normalized = description.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalized.length <= 180) {
    return normalized;
  }
  return '${normalized.substring(0, 180).trim()}...';
}

Uri preferSecureUri(Uri uri) {
  if (uri.scheme.toLowerCase() != 'http') {
    return uri;
  }

  return uri.replace(scheme: 'https');
}
