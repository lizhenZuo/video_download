import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../l10n/app_localizations.dart';
import '../models/download_models.dart';
import 'download_support.dart';

class DouyinDownloadService {
  DouyinDownloadService()
      : _dio = Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 20),
            receiveTimeout: const Duration(seconds: 25),
            headers: const {
              'User-Agent':
                  'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1',
              'Accept':
                  'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
              'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
            },
          ),
        );

  final Dio _dio;

  Future<VideoExtractionResult> extract(String rawInput) async {
    final l10n = AppLocalizations.current;
    final input = rawInput.trim();
    final rawUri = Uri.tryParse(input);

    if (rawUri == null || rawUri.scheme.isEmpty || rawUri.host.isEmpty) {
      throw VideoDownloadException(
        l10n.invalidPlatformUrl(l10n.platformName('douyin')),
      );
    }

    try {
      final uri = await _normalizeEntryUri(rawUri);
      final response = await _dio
          .getUri<String>(
            uri,
            options: Options(
              responseType: ResponseType.plain,
              followRedirects: true,
              maxRedirects: 8,
              validateStatus: (status) =>
                  status != null && status >= 200 && status < 400,
            ),
          )
          .timeout(const Duration(seconds: 20));

      final html = response.data ?? '';
      if (html.isEmpty) {
        throw VideoDownloadException(l10n.douyinNoPageContent);
      }

      final routerData = _extractRouterData(html);
      final pageData = _findVideoPageData(routerData);
      final videoInfoRes = _asMap(pageData['videoInfoRes']);
      final itemList = videoInfoRes?['item_list'] as List<dynamic>?;
      final item = itemList?.isNotEmpty == true
          ? _asMap(itemList!.first)
          : null;

      if (item == null) {
        throw VideoDownloadException(l10n.douyinNoShareData);
      }

      final author = _asMap(item['author']);
      final statistics = _asMap(item['statistics']);
      final video = _asMap(item['video']);
      final cover = _asMap(video?['cover']);
      final playAddr = _asMap(video?['play_addr']);
      final playUrls = _asStringList(playAddr?['url_list']);
      final coverUrls = _asStringList(cover?['url_list']);

      if (playUrls.isEmpty || coverUrls.isEmpty) {
        throw VideoDownloadException(l10n.douyinNoDownloadAddress);
      }

      final sourceUrl = response.realUri.toString();
      final videoId = '${item['aweme_id'] ?? ''}'.trim();
      final title =
          '${item['desc'] ?? l10n.contentTitle(l10n.platformName('douyin'))}'
              .trim();
      final authorName =
          '${author?['nickname'] ?? l10n.defaultAuthor(l10n.platformName('douyin'))}'
              .trim();
      final durationMs = _asInt(video?['duration']);
      final thumbnailUrl = Uri.parse(coverUrls.first);
      final watermarkUrl = Uri.parse(playUrls.first);
      final cleanUrl = Uri.parse(
        watermarkUrl.toString().replaceFirst('/playwm/', '/play/'),
      );
      final likeCount = _asInt(statistics?['digg_count']);
      final shareCount = _asInt(statistics?['share_count']);
      final primaryMetricLabel = likeCount > 0
          ? l10n.metricLabel(likeCount, MetricKind.likes)
          : l10n.metricLabel(shareCount, MetricKind.shares);

      final cleanVideo = DownloadAsset(
        source: VideoSource.douyin,
        id: 'douyin-clean-video',
        title: l10n.videoQualityTitle('720P'),
        subtitle: 'MP4 · ${l10n.withAudioTrack} · ${l10n.noWatermark}',
        fileStem: 'video-720p-clean',
        fileExtension: 'mp4',
        kind: DownloadAssetKind.muxedVideo,
        sizeInBytes: 0,
        url: cleanUrl,
      );

      final watermarkedVideo = DownloadAsset(
        source: VideoSource.douyin,
        id: 'douyin-watermark-video',
        title: l10n.watermarkedVideoTitle('720P'),
        subtitle: 'MP4 · ${l10n.withAudioTrack} · ${l10n.withWatermark}',
        fileStem: 'video-720p-watermark',
        fileExtension: 'mp4',
        kind: DownloadAssetKind.muxedVideo,
        sizeInBytes: 0,
        url: watermarkUrl,
      );

      final thumbnailAsset = DownloadAsset(
        source: VideoSource.douyin,
        id: 'douyin-thumbnail',
        title: l10n.coverTitle,
        subtitle: 'JPG/WEBP · ${l10n.sharePageCover}',
        fileStem: 'cover',
        fileExtension: _coverExtension(thumbnailUrl),
        kind: DownloadAssetKind.thumbnail,
        sizeInBytes: 0,
        url: thumbnailUrl,
      );

      return VideoExtractionResult(
        source: VideoSource.douyin,
        platformLabel: l10n.platformName('douyin'),
        sourceUrl: sourceUrl,
        videoId: videoId.isEmpty ? sourceUrl : videoId,
        title:
            title.isEmpty ? l10n.contentTitle(l10n.platformName('douyin')) : title,
        author: authorName.isEmpty
            ? l10n.defaultAuthor(l10n.platformName('douyin'))
            : authorName,
        thumbnailUrl: thumbnailUrl,
        duration: durationMs > 0 ? Duration(milliseconds: durationMs) : null,
        primaryMetricLabel: primaryMetricLabel,
        description: trimDescription(title),
        quickActions: [cleanVideo, watermarkedVideo, thumbnailAsset],
        muxedOptions: [cleanVideo, watermarkedVideo],
        audioOptions: const [],
        videoOnlyOptions: const [],
        imageOptions: [thumbnailAsset],
        warning: l10n.douyinWarning(l10n.platformName('douyin')),
      );
    } on VideoDownloadException {
      rethrow;
    } on DioException catch (error) {
      throw VideoDownloadException(_mapDioError(error));
    } on TimeoutException {
      throw VideoDownloadException(
        l10n.timeoutMessage(
          l10n.platformName('douyin'),
          l10n.douyinTimeoutDetail,
        ),
      );
    } on FormatException {
      throw VideoDownloadException(l10n.douyinStructureChanged);
    } catch (error) {
      throw VideoDownloadException(
        l10n.parseFailed(l10n.platformName('douyin'), error),
      );
    }
  }

  void dispose() {
    _dio.close(force: true);
  }

  Future<Uri> _normalizeEntryUri(Uri uri) async {
    final host = uri.host.toLowerCase();
    final directVideoId = _extractVideoIdFromUri(uri);

    if (directVideoId != null) {
      return Uri.parse('https://www.iesdouyin.com/share/video/$directVideoId/');
    }

    if (host.contains('iesdouyin.com') || host == 'm.douyin.com') {
      return uri;
    }

    if (host == 'v.douyin.com') {
      final response = await _dio.getUri<String>(
        uri,
        options: Options(
          responseType: ResponseType.plain,
          followRedirects: true,
          maxRedirects: 8,
          validateStatus: (status) =>
              status != null && status >= 200 && status < 400,
        ),
      );

      final resolvedUri = response.realUri;
      final resolvedVideoId = _extractVideoIdFromUri(resolvedUri);
      if (resolvedVideoId != null) {
        return Uri.parse(
          'https://www.iesdouyin.com/share/video/$resolvedVideoId/',
        );
      }

      return resolvedUri;
    }

    return uri;
  }

  Map<String, dynamic> _extractRouterData(String html) {
    final match = RegExp(
      r'window\._ROUTER_DATA\s*=\s*(\{.*?\})</script>',
      dotAll: true,
    ).firstMatch(html);

    if (match == null) {
      throw VideoDownloadException(AppLocalizations.current.douyinNoRouterData);
    }

    return _asMap(jsonDecode(match.group(1)!)) ??
        (throw VideoDownloadException(
          AppLocalizations.current.douyinRouteDataInvalid,
        ));
  }

  Map<String, dynamic> _findVideoPageData(Map<String, dynamic> routerData) {
    final loaderData = _asMap(routerData['loaderData']);
    if (loaderData == null) {
      throw VideoDownloadException(
        AppLocalizations.current.douyinLoaderDataMissing,
      );
    }

    for (final entry in loaderData.entries) {
      final value = _asMap(entry.value);
      if (value?['videoInfoRes'] != null) {
        return value!;
      }
    }

    throw VideoDownloadException(AppLocalizations.current.douyinNoVideoInfo);
  }

  Map<String, dynamic>? _asMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map(
        (key, value) => MapEntry('$key', value),
      );
    }
    return null;
  }

  List<String> _asStringList(Object? value) {
    if (value is! List) {
      return const [];
    }

    return value
        .map((item) => '$item'.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  int _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse('$value') ?? 0;
  }

  String _coverExtension(Uri url) {
    final path = url.path.toLowerCase();
    if (path.endsWith('.png')) {
      return 'png';
    }
    if (path.endsWith('.jpeg') || path.endsWith('.jpg')) {
      return 'jpg';
    }
    if (path.endsWith('.webp')) {
      return 'webp';
    }
    return 'jpg';
  }

  String _mapDioError(DioException error) {
    final l10n = AppLocalizations.current;
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return l10n.timeoutMessage(
        l10n.platformName('douyin'),
        l10n.douyinTimeoutDetail,
      );
    }

    if (error.error is SocketException) {
      return l10n.networkUnavailable(
        l10n.platformName('douyin'),
        l10n.douyinNetworkDetail,
      );
    }

    if (error.error is HandshakeException) {
      return l10n.handshakeFailed(
        l10n.platformName('douyin'),
        l10n.douyinHandshakeDetail,
      );
    }

    final statusCode = error.response?.statusCode;
    if (statusCode == 403 || statusCode == 429) {
      return l10n.requestRejected(
        l10n.platformName('douyin'),
        l10n.retryLaterDetail,
      );
    }

    return l10n.requestFailed(
      l10n.platformName('douyin'),
      error.message ?? error.type.name,
    );
  }

  String? _extractVideoIdFromUri(Uri uri) {
    final segments = uri.pathSegments.where((segment) => segment.isNotEmpty);

    for (final pair in _pairwise(segments)) {
      if (pair.$1 == 'video' && RegExp(r'^\d+$').hasMatch(pair.$2)) {
        return pair.$2;
      }
    }

    return null;
  }

  Iterable<(String, String)> _pairwise(Iterable<String> segments) sync* {
    String? previous;

    for (final segment in segments) {
      if (previous != null) {
        yield (previous, segment);
      }
      previous = segment;
    }
  }
}
