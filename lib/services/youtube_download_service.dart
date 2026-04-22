import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../l10n/app_localizations.dart';
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
    final l10n = AppLocalizations.current;
    final input = rawInput.trim();
    final videoId = VideoId.parseVideoId(input);

    if (videoId == null) {
      throw VideoDownloadException(
        l10n.invalidPlatformUrl(l10n.platformName('youtube')),
      );
    }

    try {
      final video = await _yt.videos.get(videoId).timeout(
            const Duration(seconds: 15),
          );

      if (video.isLive) {
        throw VideoDownloadException(l10n.liveStreamNotSupported);
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
              title: l10n.videoQualityTitle(stream.qualityLabel),
              subtitle:
                  '${stream.container.name.toUpperCase()} · ${stream.size} · ${l10n.withAudioTrack}',
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
              title: l10n.audioBitrateTitle(
                _formatBitrate(stream.bitrate.bitsPerSecond),
              ),
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
              title: l10n.highResVideoTitle(stream.qualityLabel),
              subtitle:
                  '${stream.container.name.toUpperCase()} · ${stream.size} · ${l10n.videoOnly}',
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
        throw VideoDownloadException(
          l10n.noVideoStreamForPlatform(l10n.platformName('youtube')),
        );
      }

      final thumbnailOption = DownloadAsset(
        source: VideoSource.youtube,
        id: 'thumbnail',
        title: l10n.thumbnailTitle,
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
        platformLabel: l10n.platformName('youtube'),
        sourceUrl: video.url,
        videoId: video.id.value,
        title: video.title,
        author: video.author,
        thumbnailUrl: Uri.parse(video.thumbnails.highResUrl),
        duration: video.duration,
        primaryMetricLabel: l10n.metricLabel(
          video.engagement.viewCount,
          MetricKind.views,
        ),
        description: trimDescription(video.description),
        quickActions: quickActions,
        muxedOptions: muxedOptions,
        audioOptions: audioOptions,
        videoOnlyOptions: videoOnlyOptions,
        imageOptions: [thumbnailOption],
        warning: videoOnlyOptions.isNotEmpty
            ? l10n.highResWarning
            : null,
      );
    } on VideoDownloadException {
      rethrow;
    } on SocketException {
      throw VideoDownloadException(
        l10n.networkUnavailable(
          l10n.platformName('youtube'),
          l10n.youtubeNetworkDetail,
        ),
      );
    } on HandshakeException {
      throw VideoDownloadException(
        l10n.handshakeFailed(
          l10n.platformName('youtube'),
          l10n.youtubeHandshakeDetail,
        ),
      );
    } on TimeoutException {
      throw VideoDownloadException(
        l10n.timeoutMessage(
          l10n.platformName('youtube'),
          l10n.youtubeTimeoutDetail,
        ),
      );
    } on VideoUnplayableException catch (error) {
      throw VideoDownloadException(_mapUnplayableMessage(error.message));
    } on Exception catch (error) {
      throw VideoDownloadException(
        l10n.parseFailed(l10n.platformName('youtube'), error),
      );
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
      throw VideoDownloadException(AppLocalizations.current.noAvailableDownloadUrl);
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
    final l10n = AppLocalizations.current;
    if (bitsPerSecond <= 0) {
      return l10n.unknownBitrate;
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

    throw VideoDownloadException(
      AppLocalizations.current.noVideoStreamForPlatform(
        AppLocalizations.current.platformName('youtube'),
      ),
    );
  }

  String _mapUnplayableMessage(String rawMessage) {
    final l10n = AppLocalizations.current;
    final message = rawMessage.toLowerCase();

    if (message.contains('age') || message.contains('confirm your age')) {
      return l10n.ageRestricted;
    }

    if (message.contains('private')) {
      return l10n.privateVideo;
    }

    if (message.contains('members-only') || message.contains('member')) {
      return l10n.membersOnlyVideo;
    }

    if (message.contains('region') || message.contains('country')) {
      return l10n.regionRestricted;
    }

    if (message.contains('sign in')) {
      return l10n.signInRequired;
    }

    return l10n.unavailableMessage;
  }
}
