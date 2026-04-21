import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../models/download_models.dart';
import 'download_support.dart';

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
      throw const VideoDownloadException('请输入有效的 YouTube 视频链接。');
    }

    try {
      final video = await _yt.videos.get(videoId).timeout(
            const Duration(seconds: 15),
          );

      if (video.isLive) {
        throw const VideoDownloadException('直播流暂不支持离线下载。');
      }

      final manifest = await _getManifestWithFallback(videoId);

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
              source: VideoSource.youtube,
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
              source: VideoSource.youtube,
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
              source: VideoSource.youtube,
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
        throw const VideoDownloadException('当前视频没有可用下载流。');
      }

      final thumbnailOption = DownloadAsset(
        source: VideoSource.youtube,
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
        source: VideoSource.youtube,
        sourceUrl: video.url,
        videoId: video.id.value,
        title: video.title,
        author: video.author,
        thumbnailUrl: Uri.parse(video.thumbnails.highResUrl),
        duration: video.duration,
        primaryMetricLabel: _compactCount(video.engagement.viewCount, '播放'),
        description: trimDescription(video.description),
        quickActions: quickActions,
        muxedOptions: muxedOptions,
        audioOptions: audioOptions,
        videoOnlyOptions: videoOnlyOptions,
        warning: videoOnlyOptions.isNotEmpty
            ? '1080p 以上通常是无音轨视频流，下载后若想直接播放，需要再与音频合并。'
            : null,
      );
    } on VideoDownloadException {
      rethrow;
    } on SocketException {
      throw const VideoDownloadException(
        '当前设备无法连接到 YouTube。请先确认网络环境可访问 YouTube，再重试。',
      );
    } on HandshakeException {
      throw const VideoDownloadException(
        '和 YouTube 建立安全连接失败。请检查当前网络或代理配置。',
      );
    } on TimeoutException {
      throw const VideoDownloadException(
        '连接 YouTube 超时。通常是当前网络无法稳定访问 YouTube。',
      );
    } on VideoUnplayableException catch (error) {
      throw VideoDownloadException(_mapUnplayableMessage(error.message));
    } on Exception catch (error) {
      throw VideoDownloadException('解析失败：$error');
    }
  }

  Future<DownloadReceipt> downloadAsset(
    DownloadAsset asset, {
    required String videoTitle,
    ProgressReporter? onProgress,
  }) async {
    final fileName = buildSafeFileName(videoTitle, asset);
    final primaryDirectory = await resolveOutputDirectory(preferShared: true);

    try {
      return await _downloadToDirectory(
        directory: primaryDirectory,
        fileName: fileName,
        asset: asset,
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
      throw const VideoDownloadException('下载项缺少可用的文件地址。');
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

  Future<StreamManifest> _getManifestWithFallback(String videoId) async {
    final attempts = <({
      String label,
      List<YoutubeApiClient> clients,
      Duration timeout,
    })>[
      (
        label: 'android',
        clients: [YoutubeApiClient.android],
        timeout: const Duration(seconds: 18),
      ),
      (
        label: 'androidVr',
        clients: [YoutubeApiClient.androidVr],
        timeout: const Duration(seconds: 18),
      ),
      (
        label: 'tv',
        clients: [YoutubeApiClient.tv],
        timeout: const Duration(seconds: 22),
      ),
    ];

    Object? lastError;

    for (final attempt in attempts) {
      try {
        return await _yt.videos.streamsClient
            .getManifest(videoId, ytClients: attempt.clients)
            .timeout(attempt.timeout);
      } catch (error) {
        lastError = error;
      }
    }

    if (lastError case Exception exception) {
      throw exception;
    }
    if (lastError case Error error) {
      throw error;
    }

    throw const VideoDownloadException('当前视频没有可用下载流。');
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

  String _compactCount(int value, String suffix) {
    if (value >= 100000000) {
      return '${(value / 100000000).toStringAsFixed(1)}亿$suffix';
    }
    if (value >= 10000) {
      return '${(value / 10000).toStringAsFixed(1)}万$suffix';
    }
    return '$value $suffix';
  }
}
