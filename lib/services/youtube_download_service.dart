import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../models/download_models.dart';

typedef ProgressReporter = void Function(double progress);

class YoutubeDownloadService {
  YoutubeDownloadService()
      : _yt = YoutubeExplode(),
        _dio = Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 20),
            receiveTimeout: const Duration(minutes: 5),
          ),
        );

  final YoutubeExplode _yt;
  final Dio _dio;

  Future<VideoExtractionResult> extract(String rawInput) async {
    final input = rawInput.trim();
    final videoId = VideoId.parseVideoId(input);

    if (videoId == null) {
      throw const YoutubeDownloadException('请输入有效的 YouTube 视频链接。');
    }

    try {
      final video = await _yt.videos.get(videoId);

      if (video.isLive) {
        throw const YoutubeDownloadException('直播流暂不支持离线下载。');
      }

      final manifest = await _yt.videos.streamsClient.getManifest(
        videoId,
        ytClients: [
          YoutubeApiClient.android,
          YoutubeApiClient.ios,
          YoutubeApiClient.androidVr,
          YoutubeApiClient.tv,
        ],
      ).timeout(const Duration(seconds: 20));

      final muxed = _uniqueBy(
        manifest.muxed.sortByVideoQuality(),
        (stream) => '${stream.qualityLabel}-${stream.container.name}',
      );
      final audio = _uniqueBy(
        manifest.audioOnly.sortByBitrate(),
        (stream) =>
            '${stream.bitrate.bitsPerSecond}-${stream.container.name}-${stream.audioTrack?.id ?? 'default'}',
      );
      final videoOnly = _uniqueBy(
        manifest.videoOnly.sortByVideoQuality(),
        (stream) => '${stream.qualityLabel}-${stream.container.name}',
      );

      final muxedOptions = muxed
          .map(
            (stream) => DownloadAsset(
              id: 'muxed-${stream.tag}',
              title: '视频 ${stream.qualityLabel}',
              subtitle:
                  '${stream.container.name.toUpperCase()} · ${stream.size} · 带音轨',
              fileStem: 'video-${_slug(stream.qualityLabel)}',
              fileExtension: stream.container.name,
              kind: DownloadAssetKind.muxedVideo,
              sizeInBytes: stream.size.totalBytes,
              streamInfo: stream,
            ),
          )
          .toList(growable: false);

      final audioOptions = audio
          .take(4)
          .map(
            (stream) => DownloadAsset(
              id: 'audio-${stream.tag}-${stream.audioTrack?.id ?? 'default'}',
              title: '音频 ${_formatBitrate(stream.bitrate.bitsPerSecond)}',
              subtitle:
                  '${stream.container.name.toUpperCase()} · ${stream.size}${stream.audioTrack == null ? '' : ' · ${stream.audioTrack!.displayName}'}',
              fileStem:
                  'audio-${_slug(_formatBitrate(stream.bitrate.bitsPerSecond))}',
              fileExtension: stream.container.name,
              kind: DownloadAssetKind.audioOnly,
              sizeInBytes: stream.size.totalBytes,
              streamInfo: stream,
            ),
          )
          .toList(growable: false);

      final videoOnlyOptions = videoOnly
          .take(8)
          .map(
            (stream) => DownloadAsset(
              id: 'video-only-${stream.tag}',
              title: '高分辨率 ${stream.qualityLabel}',
              subtitle:
                  '${stream.container.name.toUpperCase()} · ${stream.size} · 仅视频',
              fileStem: 'video-only-${_slug(stream.qualityLabel)}',
              fileExtension: stream.container.name,
              kind: DownloadAssetKind.videoOnly,
              sizeInBytes: stream.size.totalBytes,
              streamInfo: stream,
              requiresMuxing: true,
            ),
          )
          .toList(growable: false);

      if (muxedOptions.isEmpty &&
          audioOptions.isEmpty &&
          videoOnlyOptions.isEmpty) {
        throw const YoutubeDownloadException('当前视频没有可用下载流。');
      }

      final thumbnailOption = DownloadAsset(
        id: 'thumbnail',
        title: '封面图',
        subtitle: 'JPG · High Resolution',
        fileStem: 'cover',
        fileExtension: 'jpg',
        kind: DownloadAssetKind.thumbnail,
        sizeInBytes: 0,
        url: Uri.parse(video.thumbnails.highResUrl),
      );

      final quickActions = <DownloadAsset>[
        if (muxedOptions.isNotEmpty) muxedOptions.first,
        if (audioOptions.isNotEmpty) audioOptions.first,
        thumbnailOption,
      ];

      return VideoExtractionResult(
        sourceUrl: video.url,
        videoId: video.id.value,
        title: video.title,
        author: video.author,
        thumbnailUrl: Uri.parse(video.thumbnails.highResUrl),
        duration: video.duration,
        viewCount: video.engagement.viewCount,
        description: _trimDescription(video.description),
        quickActions: quickActions,
        muxedOptions: muxedOptions,
        audioOptions: audioOptions,
        videoOnlyOptions: videoOnlyOptions,
        warning: videoOnlyOptions.isNotEmpty
            ? '1080p 以上通常是无音轨视频流，下载后若想直接播放，需要再与音频合并。'
            : null,
      );
    } on YoutubeDownloadException {
      rethrow;
    } on SocketException {
      throw const YoutubeDownloadException(
        '当前设备无法连接到 YouTube。请先确认网络环境可访问 YouTube，再重试。',
      );
    } on HandshakeException {
      throw const YoutubeDownloadException(
        '和 YouTube 建立安全连接失败。请检查当前网络或代理配置。',
      );
    } on TimeoutException {
      throw const YoutubeDownloadException(
        '连接 YouTube 超时。通常是当前网络无法稳定访问 YouTube。',
      );
    } on VideoUnplayableException catch (error) {
      throw YoutubeDownloadException(_mapUnplayableMessage(error.message));
    } on Exception catch (error) {
      throw YoutubeDownloadException('解析失败：$error');
    }
  }

  Future<DownloadReceipt> downloadAsset(
    DownloadAsset asset, {
    required String videoTitle,
    ProgressReporter? onProgress,
  }) async {
    final fileName = _buildSafeFileName(videoTitle, asset);
    final primaryDirectory = await _resolveOutputDirectory(preferShared: true);

    try {
      return await _downloadToDirectory(
        directory: primaryDirectory,
        fileName: fileName,
        asset: asset,
        onProgress: onProgress,
      );
    } on FileSystemException {
      final fallbackDirectory = await _resolveOutputDirectory(
        preferShared: false,
      );

      if (fallbackDirectory.path == primaryDirectory.path) {
        rethrow;
      }

      return _downloadToDirectory(
        directory: fallbackDirectory,
        fileName: fileName,
        asset: asset,
        onProgress: onProgress,
      );
    }
  }

  Future<DownloadReceipt> _downloadToDirectory({
    required Directory directory,
    required String fileName,
    required DownloadAsset asset,
    required ProgressReporter? onProgress,
  }) async {
    final file = File('${directory.path}/$fileName');

    if (await file.exists()) {
      await file.delete();
    }

    if (asset.streamInfo != null) {
      await _writeStreamToFile(
        file,
        asset.streamInfo!,
        onProgress: onProgress,
      );
    } else if (asset.url != null) {
      await _dio.download(
        asset.url.toString(),
        file.path,
        onReceiveProgress: (received, total) {
          if (total <= 0 || onProgress == null) {
            return;
          }
          onProgress(received / total);
        },
      );
    } else {
      throw const YoutubeDownloadException('下载项缺少可用的文件地址。');
    }

    return DownloadReceipt(
      filePath: file.path,
      fileName: fileName,
      asset: asset,
    );
  }

  Future<void> _writeStreamToFile(
    File file,
    StreamInfo streamInfo, {
    ProgressReporter? onProgress,
  }) async {
    final output = file.openWrite(mode: FileMode.writeOnly);
    final totalBytes = streamInfo.size.totalBytes;
    var receivedBytes = 0;

    try {
      await for (final chunk in _yt.videos.streamsClient.get(streamInfo)) {
        output.add(chunk);
        receivedBytes += chunk.length;

        if (onProgress != null && totalBytes > 0) {
          onProgress(receivedBytes / totalBytes);
        }
      }
    } finally {
      await output.flush();
      await output.close();
    }
  }

  Future<Directory> _resolveOutputDirectory(
      {required bool preferShared}) async {
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

  void dispose() {
    _dio.close(force: true);
    _yt.close();
  }

  List<T> _uniqueBy<T>(Iterable<T> items, String Function(T item) keyOf) {
    final seen = <String>{};
    final result = <T>[];

    for (final item in items) {
      final key = keyOf(item);
      if (seen.add(key)) {
        result.add(item);
      }
    }

    return result;
  }

  String _sanitizeFileName(String input) {
    final cleaned = input
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (cleaned.isEmpty) {
      return 'youtube-media';
    }

    return cleaned.length > 80 ? cleaned.substring(0, 80).trim() : cleaned;
  }

  String _buildSafeFileName(String videoTitle, DownloadAsset asset) {
    final safeTitle = _sanitizeFileName(videoTitle);
    final safeStem = _sanitizeFileName(asset.fileStem);
    final extension = '.${asset.fileExtension}';
    final suffix = '-$safeStem';
    const maxFileNameBytes = 180;
    final reservedBytes = utf8.encode('$suffix$extension').length;
    final titleBudget = maxFileNameBytes - reservedBytes;
    final truncatedTitle = _truncateUtf8(
      safeTitle.isEmpty ? 'youtube-media' : safeTitle,
      titleBudget > 24 ? titleBudget : 24,
    );

    return '$truncatedTitle$suffix$extension';
  }

  String _truncateUtf8(String input, int maxBytes) {
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
    return result.isEmpty ? 'youtube-media' : result;
  }

  String _slug(String input) => input
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');

  String _formatBitrate(int bitsPerSecond) {
    if (bitsPerSecond <= 0) {
      return '未知码率';
    }
    final kbps = bitsPerSecond / 1024;
    return '${kbps.toStringAsFixed(kbps >= 100 ? 0 : 1)} kbps';
  }

  String _trimDescription(String description) {
    final normalized = description.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= 180) {
      return normalized;
    }
    return '${normalized.substring(0, 180).trim()}...';
  }

  String _mapUnplayableMessage(String rawMessage) {
    final message = rawMessage.toLowerCase();

    if (message.contains('age') || message.contains('confirm your age')) {
      return '这个视频触发了年龄限制，当前解析方式拿不到可下载流。';
    }

    if (message.contains('private')) {
      return '这个视频是私有视频，无法解析下载。';
    }

    if (message.contains('members-only') || message.contains('member')) {
      return '这个视频是会员专属内容，当前无法解析下载。';
    }

    if (message.contains('region') || message.contains('country')) {
      return '这个视频受地区限制，当前网络区域拿不到可下载流。';
    }

    if (message.contains('sign in')) {
      return '这个视频需要登录态才能访问，当前解析方式拿不到可下载流。';
    }

    return '当前视频不可播放，或者当前网络环境无法直接拿到 YouTube 媒体流。';
  }
}

class YoutubeDownloadException implements Exception {
  const YoutubeDownloadException(this.message);

  final String message;

  @override
  String toString() => message;
}
