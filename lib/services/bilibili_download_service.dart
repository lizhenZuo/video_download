import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

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
    final input = rawInput.trim();
    final rawUri = Uri.tryParse(input);

    if (rawUri == null || rawUri.scheme.isEmpty || rawUri.host.isEmpty) {
      throw const VideoDownloadException('请输入有效的哔哩哔哩视频链接。');
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
        throw const VideoDownloadException('哔哩哔哩页面没有返回可解析内容。');
      }

      final state = extractBilibiliInitialState(html);
      final video = _asMap(state['video']);
      final viewInfo = _asMap(video?['viewInfo']);
      if (viewInfo == null) {
        throw const VideoDownloadException('当前哔哩哔哩页面没有可用的视频信息。');
      }

      final playItems = _asList(video?['playUrlInfo'])
          .map(_asMap)
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);
      if (playItems.isEmpty) {
        throw const VideoDownloadException('当前哔哩哔哩视频没有可用的下载地址。');
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

      final title = '${viewInfo['title'] ?? '哔哩哔哩视频'}'.trim();
      final author = '${owner?['name'] ?? '哔哩哔哩作者'}'.trim();
      final description = '${viewInfo['desc'] ?? ''}'.trim();
      final durationSeconds = _asInt(viewInfo['duration']);

      final thumbnailUrl = _parseSecureUri(viewInfo['pic']) ??
          _parseSecureUri(pages.firstOrNull?['first_frame']) ??
          (throw const VideoDownloadException('当前哔哩哔哩视频没有可用封面。'));

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
            title: muxedOptions.isEmpty ? '视频' : '视频 ${muxedOptions.length + 1}',
            subtitle:
                '${_extensionLabel(extension)} · 带音轨直链$durationLabel',
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
        throw const VideoDownloadException('当前哔哩哔哩视频没有可用的视频流。');
      }

      final imageOptions = <DownloadAsset>[
        DownloadAsset(
          source: VideoSource.bilibili,
          id: 'bilibili-cover',
          title: '封面图',
          subtitle:
              '${_extensionLabel(_fileExtensionForUrl(thumbnailUrl, fallback: 'jpg'))} · 页面封面',
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
            title: '首帧图',
            subtitle:
                '${_extensionLabel(_fileExtensionForUrl(firstFrame, fallback: 'jpg'))} · 页面首帧',
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
        platformLabel: '哔哩哔哩',
        sourceUrl: sourceUrl,
        videoId: bvid.isEmpty ? sourceUrl : bvid,
        title: title.isEmpty ? '哔哩哔哩视频' : title,
        author: author.isEmpty ? '哔哩哔哩作者' : author,
        thumbnailUrl: thumbnailUrl,
        duration: durationSeconds > 0 ? Duration(seconds: durationSeconds) : null,
        primaryMetricLabel: viewCount > 0
            ? _compactCount(viewCount, '播放')
            : '${muxedOptions.length} 个下载项',
        description: trimDescription(description.isEmpty ? title : description),
        quickActions: quickActions,
        muxedOptions: muxedOptions,
        audioOptions: const [],
        videoOnlyOptions: const [],
        imageOptions: imageOptions,
        thumbnailHeaders: _downloadHeaders,
        warning: '当前通过哔哩哔哩移动页直接解析，视频和封面直链都有时效，解析后建议尽快下载。',
      );
    } on VideoDownloadException {
      rethrow;
    } on DioException catch (error) {
      throw VideoDownloadException(_mapDioError(error));
    } on TimeoutException {
      throw const VideoDownloadException('连接哔哩哔哩超时，请稍后重试。');
    } on FormatException {
      throw const VideoDownloadException('当前哔哩哔哩页面结构已变化，暂时无法解析。');
    } catch (error) {
      throw VideoDownloadException('解析哔哩哔哩失败：$error');
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

      throw const VideoDownloadException('当前短链没有解析到可用的哔哩哔哩视频地址。');
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

  String _compactCount(int value, String suffix) {
    if (value >= 100000000) {
      return '${(value / 100000000).toStringAsFixed(1)}亿$suffix';
    }
    if (value >= 10000) {
      return '${(value / 10000).toStringAsFixed(1)}万$suffix';
    }
    return '$value $suffix';
  }

  String _mapDioError(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return '连接哔哩哔哩超时，请稍后重试。';
    }

    if (error.error is SocketException) {
      return '当前设备无法连接到哔哩哔哩，请检查网络后重试。';
    }

    if (error.error is HandshakeException) {
      return '和哔哩哔哩建立安全连接失败，请检查当前网络环境。';
    }

    final statusCode = error.response?.statusCode;
    if (statusCode == 403 || statusCode == 429) {
      return '哔哩哔哩当前暂时拒绝了这次请求，稍后重试更稳。';
    }

    return '哔哩哔哩请求失败：${error.message ?? error.type.name}';
  }
}
