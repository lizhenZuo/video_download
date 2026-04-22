import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../l10n/app_localizations.dart';
import '../models/download_models.dart';
import 'download_support.dart';

Map<String, dynamic> extractBilibiliInitialState(String html) {
  final pattern = RegExp(
    r'window\.__INITIAL_STATE__=(\{.*?\})\s*;\s*(?:\(function\(\)\{var s;|</script>)',
    dotAll: true,
  );
  final match = pattern.firstMatch(html);
  if (match == null) {
    throw const FormatException('missing bilibili initial state');
  }

  final decoded = jsonDecode(match.group(1)!);
  if (decoded is Map<String, dynamic>) {
    return decoded;
  }
  if (decoded is Map) {
    return decoded.map((key, value) => MapEntry('$key', value));
  }

  throw const FormatException('unexpected bilibili initial state payload');
}

class BilibiliDownloadService {
  BilibiliDownloadService()
      : _dio = Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 20),
            receiveTimeout: const Duration(seconds: 30),
            headers: const {
              'User-Agent': _mobileUserAgent,
              'Accept':
                  'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
              'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
            },
          ),
        );

  static const String _mobileUserAgent =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1';

  static const Map<String, String> _downloadHeaders = {
    'User-Agent': _mobileUserAgent,
    'Referer': 'https://www.bilibili.com/',
  };

  final Dio _dio;

  Future<VideoExtractionResult> extract(String rawInput) async {
    final l10n = AppLocalizations.current;
    final input = rawInput.trim();
    final rawUri = Uri.tryParse(input);

    if (rawUri == null || rawUri.scheme.isEmpty || rawUri.host.isEmpty) {
      throw VideoDownloadException(
        l10n.invalidPlatformUrl(l10n.platformName('bilibili')),
      );
    }

    try {
      final mobileUri = await _normalizeEntryUri(rawUri);
      final response = await _dio
          .getUri<String>(
            mobileUri,
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
        throw VideoDownloadException(l10n.bilibiliNoPageContent);
      }

      final state = extractBilibiliInitialState(html);
      final video = _asMap(state['video']);
      final viewInfo = _asMap(video?['viewInfo']);
      if (viewInfo == null) {
        throw VideoDownloadException(l10n.bilibiliNoVideoInfo);
      }

      final playItems = _asList(video?['playUrlInfo'])
          .map(_asMap)
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);
      if (playItems.isEmpty) {
        throw VideoDownloadException(l10n.bilibiliNoDownloadAddress);
      }

      final bvid = '${viewInfo['bvid'] ?? ''}'.trim();
      final sourceUrl = bvid.isNotEmpty
          ? 'https://www.bilibili.com/video/$bvid/'
          : response.realUri.toString();
      final owner = _asMap(viewInfo['owner']);
      final stat = _asMap(viewInfo['stat']);
      final pages = _asList(viewInfo['pages'])
          .map(_asMap)
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);

      final title =
          '${viewInfo['title'] ?? l10n.contentTitle(l10n.platformName('bilibili'))}'
              .trim();
      final author =
          '${owner?['name'] ?? l10n.defaultAuthor(l10n.platformName('bilibili'))}'
              .trim();
      final description = '${viewInfo['desc'] ?? ''}'.trim();
      final durationSeconds = _asInt(viewInfo['duration']);

      final thumbnailUrl = _parseSecureUri(viewInfo['pic']) ??
          _parseSecureUri(pages.firstOrNull?['first_frame']) ??
          (throw VideoDownloadException(l10n.bilibiliNoCover));

      final muxedOptions = <DownloadAsset>[];
      final addedVideoUrls = <String>{};
      for (final entry in playItems) {
        final videoUrl = _parseSecureUri(entry['url']);
        if (videoUrl == null || !addedVideoUrls.add(videoUrl.toString())) {
          continue;
        }

        final order = _asInt(entry['order']);
        final extension = _fileExtensionForUrl(videoUrl, fallback: 'mp4');
        final durationLabel = durationSeconds > 0 ? ' · ${durationSeconds}s' : '';

        muxedOptions.add(
          DownloadAsset(
            source: VideoSource.bilibili,
            id: 'bilibili-video-$order',
            title: muxedOptions.isEmpty
                ? l10n.videoTitle
                : l10n.videoTitleWithIndex(muxedOptions.length + 1),
            subtitle:
                '${_extensionLabel(extension)} · ${l10n.withAudioTrack} · ${l10n.directLink}$durationLabel',
            fileStem: muxedOptions.isEmpty
                ? 'video'
                : 'video-${muxedOptions.length + 1}',
            fileExtension: extension,
            kind: DownloadAssetKind.muxedVideo,
            sizeInBytes: _asInt(entry['size']),
            url: videoUrl,
            headers: _downloadHeaders,
          ),
        );
      }

      if (muxedOptions.isEmpty) {
        throw VideoDownloadException(l10n.bilibiliNoVideoStream);
      }

      final imageOptions = <DownloadAsset>[
        DownloadAsset(
          source: VideoSource.bilibili,
          id: 'bilibili-cover',
          title: l10n.coverTitle,
          subtitle:
              '${_extensionLabel(_fileExtensionForUrl(thumbnailUrl, fallback: 'jpg'))} · ${l10n.pageCover}',
          fileStem: 'cover',
          fileExtension: _fileExtensionForUrl(thumbnailUrl, fallback: 'jpg'),
          kind: DownloadAssetKind.thumbnail,
          sizeInBytes: 0,
          url: thumbnailUrl,
          headers: _downloadHeaders,
        ),
      ];

      final firstFrame = _parseSecureUri(pages.firstOrNull?['first_frame']);
      if (firstFrame != null && firstFrame.toString() != thumbnailUrl.toString()) {
        imageOptions.add(
          DownloadAsset(
            source: VideoSource.bilibili,
            id: 'bilibili-first-frame',
            title: l10n.firstFrameTitle,
            subtitle:
                '${_extensionLabel(_fileExtensionForUrl(firstFrame, fallback: 'jpg'))} · ${l10n.pageFirstFrame}',
            fileStem: 'first-frame',
            fileExtension: _fileExtensionForUrl(firstFrame, fallback: 'jpg'),
            kind: DownloadAssetKind.image,
            sizeInBytes: 0,
            url: firstFrame,
            headers: _downloadHeaders,
          ),
        );
      }

      final quickActions = <DownloadAsset>[
        muxedOptions.first,
        imageOptions.first,
        if (imageOptions.length > 1) imageOptions[1],
      ];

      final viewCount = _asInt(stat?['view']);

      return VideoExtractionResult(
        source: VideoSource.bilibili,
        platformLabel: l10n.platformName('bilibili'),
        sourceUrl: sourceUrl,
        videoId: bvid.isEmpty ? sourceUrl : bvid,
        title: title.isEmpty
            ? l10n.contentTitle(l10n.platformName('bilibili'))
            : title,
        author: author.isEmpty
            ? l10n.defaultAuthor(l10n.platformName('bilibili'))
            : author,
        thumbnailUrl: thumbnailUrl,
        duration: durationSeconds > 0 ? Duration(seconds: durationSeconds) : null,
        primaryMetricLabel: viewCount > 0
            ? l10n.metricLabel(viewCount, MetricKind.views)
            : l10n.downloadItemsCount(muxedOptions.length),
        description: trimDescription(description.isEmpty ? title : description),
        quickActions: quickActions,
        muxedOptions: muxedOptions,
        audioOptions: const [],
        videoOnlyOptions: const [],
        imageOptions: imageOptions,
        thumbnailHeaders: _downloadHeaders,
        warning: l10n.bilibiliWarning(l10n.platformName('bilibili')),
      );
    } on VideoDownloadException {
      rethrow;
    } on DioException catch (error) {
      throw VideoDownloadException(_mapDioError(error));
    } on TimeoutException {
      throw VideoDownloadException(
        l10n.timeoutMessage(
          l10n.platformName('bilibili'),
          l10n.bilibiliTimeoutDetail,
        ),
      );
    } on FormatException {
      throw VideoDownloadException(l10n.bilibiliStructureChanged);
    } catch (error) {
      throw VideoDownloadException(
        l10n.parseFailed(l10n.platformName('bilibili'), error),
      );
    }
  }

  void dispose() {
    _dio.close(force: true);
  }

  Future<Uri> _normalizeEntryUri(Uri uri) async {
    final directVideoId = _extractVideoIdFromUri(uri);
    if (directVideoId != null) {
      return Uri.parse('https://m.bilibili.com/video/$directVideoId/');
    }

    final host = uri.host.toLowerCase();
    if (host == 'b23.tv') {
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

      final resolvedVideoId = _extractVideoIdFromUri(response.realUri);
      if (resolvedVideoId != null) {
        return Uri.parse('https://m.bilibili.com/video/$resolvedVideoId/');
      }

      throw VideoDownloadException(AppLocalizations.current.bilibiliShortLinkInvalid);
    }

    return uri.replace(
      scheme: 'https',
      host: 'm.bilibili.com',
      query: '',
      fragment: '',
    );
  }

  String? _extractVideoIdFromUri(Uri uri) {
    for (final segment in uri.pathSegments.reversed) {
      final value = segment.trim();
      if (RegExp(r'^(BV[0-9A-Za-z]+|av\d+)$', caseSensitive: false)
          .hasMatch(value)) {
        return value;
      }
    }

    final bvid = uri.queryParameters['bvid']?.trim();
    if (bvid != null && bvid.isNotEmpty) {
      return bvid;
    }

    return null;
  }

  Map<String, dynamic>? _asMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, value) => MapEntry('$key', value));
    }
    return null;
  }

  List<dynamic> _asList(Object? value) {
    if (value is List) {
      return value;
    }
    return const [];
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

  Uri? _parseSecureUri(Object? value) {
    final raw = '$value'.trim();
    if (raw.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(raw);
    if (uri == null) {
      return null;
    }

    return preferSecureUri(uri);
  }

  String _fileExtensionForUrl(Uri url, {required String fallback}) {
    final path = url.path.toLowerCase();
    final dotIndex = path.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == path.length - 1) {
      return fallback;
    }

    final extension = path.substring(dotIndex + 1);
    if (extension.length > 8 || extension.contains('/')) {
      return fallback;
    }

    return extension;
  }

  String _extensionLabel(String extension) => extension.toUpperCase();

  String _mapDioError(DioException error) {
    final l10n = AppLocalizations.current;
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return l10n.timeoutMessage(
        l10n.platformName('bilibili'),
        l10n.bilibiliTimeoutDetail,
      );
    }

    if (error.error is SocketException) {
      return l10n.networkUnavailable(
        l10n.platformName('bilibili'),
        l10n.bilibiliNetworkDetail,
      );
    }

    if (error.error is HandshakeException) {
      return l10n.handshakeFailed(
        l10n.platformName('bilibili'),
        l10n.bilibiliHandshakeDetail,
      );
    }

    final statusCode = error.response?.statusCode;
    if (statusCode == 403 || statusCode == 429) {
      return l10n.requestRejected(
        l10n.platformName('bilibili'),
        l10n.retryLaterDetail,
      );
    }

    return l10n.requestFailed(
      l10n.platformName('bilibili'),
      error.message ?? error.type.name,
    );
  }
}
