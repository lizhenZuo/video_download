import 'dart:io';

import 'package:dio/dio.dart';

import '../models/download_models.dart';
import 'download_support.dart';

class DirectDownloadService {
  DirectDownloadService()
      : _dio = Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 20),
            receiveTimeout: const Duration(minutes: 5),
          ),
        );

  final Dio _dio;

  Future<DownloadReceipt> downloadAsset(
    DownloadAsset asset, {
    required String videoTitle,
    ProgressReporter? onProgress,
  }) async {
    final url = asset.url;
    if (url == null) {
      throw const VideoDownloadException('下载项缺少可用的文件地址。');
    }

    final fileName = buildSafeFileName(videoTitle, asset);
    final primaryDirectory = await resolveOutputDirectory(preferShared: true);

    try {
      return await _downloadToDirectory(
        directory: primaryDirectory,
        fileName: fileName,
        asset: asset,
        url: url,
        onProgress: onProgress,
      );
    } on FileSystemException {
      final fallbackDirectory = await resolveOutputDirectory(
        preferShared: false,
      );

      if (fallbackDirectory.path == primaryDirectory.path) {
        rethrow;
      }

      return _downloadToDirectory(
        directory: fallbackDirectory,
        fileName: fileName,
        asset: asset,
        url: url,
        onProgress: onProgress,
      );
    }
  }

  Future<DownloadReceipt> _downloadToDirectory({
    required Directory directory,
    required String fileName,
    required DownloadAsset asset,
    required Uri url,
    required ProgressReporter? onProgress,
  }) async {
    final file = File('${directory.path}/$fileName');

    if (await file.exists()) {
      await file.delete();
    }

    await _dio.download(
      url.toString(),
      file.path,
      options: Options(headers: asset.headers),
      onReceiveProgress: (received, total) {
        if (total <= 0 || onProgress == null) {
          return;
        }
        onProgress(received / total);
      },
    );

    return DownloadReceipt(
      filePath: file.path,
      fileName: fileName,
      asset: asset,
    );
  }

  void dispose() {
    _dio.close(force: true);
  }
}
