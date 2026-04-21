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
