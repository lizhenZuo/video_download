import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

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
    final input = rawInput.trim();
    final rawUri = Uri.tryParse(input);

    if (rawUri == null || rawUri.scheme.isEmpty || rawUri.host.isEmpty) {
      throw const VideoDownloadException('请输入有效的抖音视频链接。');
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
        throw const VideoDownloadException('抖音页面没有返回可解析内容。');
      }

      final routerData = _extractRouterData(html);
      final pageData = _findVideoPageData(routerData);
      final videoInfoRes = _asMap(pageData['videoInfoRes']);
      final itemList = videoInfoRes?['item_list'] as List<dynamic>?;
      final item = itemList?.isNotEmpty == true
          ? _asMap(itemList!.first)
          : null;

      if (item == null) {
        throw const VideoDownloadException('当前抖音视频没有可用的分享页数据。');
      }

      final author = _asMap(item['author']);
      final statistics = _asMap(item['statistics']);
      final video = _asMap(item['video']);
      final cover = _asMap(video?['cover']);
      final playAddr = _asMap(video?['play_addr']);
      final playUrls = _asStringList(playAddr?['url_list']);
      final coverUrls = _asStringList(cover?['url_list']);

      if (playUrls.isEmpty || coverUrls.isEmpty) {
        throw const VideoDownloadException('当前抖音视频没有可用的下载地址。');
      }

      final sourceUrl = response.realUri.toString();
      final videoId = '${item['aweme_id'] ?? ''}'.trim();
      final title = '${item['desc'] ?? '抖音视频'}'.trim();
      final authorName = '${author?['nickname'] ?? '抖音作者'}'.trim();
      final durationMs = _asInt(video?['duration']);
      final thumbnailUrl = Uri.parse(coverUrls.first);
      final watermarkUrl = Uri.parse(playUrls.first);
      final cleanUrl = Uri.parse(
        watermarkUrl.toString().replaceFirst('/playwm/', '/play/'),
      );
      final likeCount = _asInt(statistics?['digg_count']);
      final shareCount = _asInt(statistics?['share_count']);
      final primaryMetricLabel = likeCount > 0
          ? _compactCount(likeCount, '点赞')
          : _compactCount(shareCount, '分享');

      final cleanVideo = DownloadAsset(
        source: VideoSource.douyin,
        id: 'douyin-clean-video',
        title: '视频 720P',
        subtitle: 'MP4 · 带音轨 · 无水印',
        fileStem: 'video-720p-clean',
        fileExtension: 'mp4',
        kind: DownloadAssetKind.muxedVideo,
        sizeInBytes: 0,
        url: cleanUrl,
      );

      final watermarkedVideo = DownloadAsset(
        source: VideoSource.douyin,
        id: 'douyin-watermark-video',
        title: '视频 720P（水印）',
        subtitle: 'MP4 · 带音轨 · 带水印',
        fileStem: 'video-720p-watermark',
        fileExtension: 'mp4',
        kind: DownloadAssetKind.muxedVideo,
        sizeInBytes: 0,
        url: watermarkUrl,
      );

      final thumbnailAsset = DownloadAsset(
        source: VideoSource.douyin,
        id: 'douyin-thumbnail',
        title: '封面图',
        subtitle: 'JPG/WEBP · 分享页封面',
        fileStem: 'cover',
        fileExtension: _coverExtension(thumbnailUrl),
        kind: DownloadAssetKind.thumbnail,
        sizeInBytes: 0,
        url: thumbnailUrl,
      );

      return VideoExtractionResult(
        source: VideoSource.douyin,
        sourceUrl: sourceUrl,
        videoId: videoId.isEmpty ? sourceUrl : videoId,
        title: title.isEmpty ? '抖音视频' : title,
        author: authorName.isEmpty ? '抖音作者' : authorName,
        thumbnailUrl: thumbnailUrl,
        duration: durationMs > 0 ? Duration(milliseconds: durationMs) : null,
        primaryMetricLabel: primaryMetricLabel,
        description: trimDescription(title),
        quickActions: [cleanVideo, watermarkedVideo, thumbnailAsset],
        muxedOptions: [cleanVideo, watermarkedVideo],
        audioOptions: const [],
        videoOnlyOptions: const [],
        warning: '当前通过抖音分享页解析，只提供直连 MP4 视频和封面图；独立音频与更多清晰度暂不提供。',
      );
    } on VideoDownloadException {
      rethrow;
    } on DioException catch (error) {
      throw VideoDownloadException(_mapDioError(error));
    } on TimeoutException {
      throw const VideoDownloadException(
        '连接抖音超时。通常是当前网络无法稳定访问抖音分享页。',
      );
    } on FormatException {
      throw const VideoDownloadException('当前抖音页面结构已变化，暂时无法解析。');
    } catch (error) {
      throw VideoDownloadException('解析抖音失败：$error');
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
      throw const VideoDownloadException('当前抖音页面没有可解析的路由数据。');
    }

    return _asMap(jsonDecode(match.group(1)!)) ??
        (throw const VideoDownloadException('抖音路由数据格式异常。'));
  }

  Map<String, dynamic> _findVideoPageData(Map<String, dynamic> routerData) {
    final loaderData = _asMap(routerData['loaderData']);
    if (loaderData == null) {
      throw const VideoDownloadException('抖音页面缺少 loaderData。');
    }

    for (final entry in loaderData.entries) {
      final value = _asMap(entry.value);
      if (value?['videoInfoRes'] != null) {
        return value!;
      }
    }

    throw const VideoDownloadException('当前抖音页面没有视频信息。');
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

  String _compactCount(int value, String suffix) {
    if (value >= 100000000) {
      return '${(value / 100000000).toStringAsFixed(1)}亿$suffix';
    }
    if (value >= 10000) {
      return '${(value / 10000).toStringAsFixed(1)}万$suffix';
    }
    return '$value $suffix';
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
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return '连接抖音超时。通常是当前网络无法稳定访问抖音分享页。';
    }

    if (error.error is SocketException) {
      return '当前设备无法连接到抖音。请先确认网络环境可访问抖音，再重试。';
    }

    if (error.error is HandshakeException) {
      return '和抖音建立安全连接失败。请检查当前网络或代理配置。';
    }

    final statusCode = error.response?.statusCode;
    if (statusCode == 403 || statusCode == 429) {
      return '抖音暂时拒绝了这次解析请求，稍后重试更稳。';
    }

    return '抖音页面请求失败：${error.message ?? error.type.name}';
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
