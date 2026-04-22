import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import '../l10n/app_localizations.dart';
import '../models/download_models.dart';
import 'download_support.dart';

class SnapAnyDownloadService {
  static const String _locale = 'zh';
  static const String _signatureSecret = '6HTugjCXxR';
  static const String _browserUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/139.0.0.0 Safari/537.36';

  SnapAnyDownloadService()
      : _dio = Dio(
          BaseOptions(
            baseUrl: 'https://api.snapany.com',
            connectTimeout: const Duration(seconds: 20),
            receiveTimeout: const Duration(seconds: 30),
            contentType: Headers.jsonContentType,
            headers: const {
              'Accept': 'application/json, text/plain, */*',
              'Accept-Language': _locale,
              'User-Agent': _browserUserAgent,
            },
          ),
        );

  static const List<_SnapAnyPlatform> _platforms = [
    _SnapAnyPlatform(
      site: 'tiktok',
      label: 'TikTok',
      hostPatterns: [
        'tiktok',
        'tiktokv',
        'tiktokcdn',
        'musical',
        'musemuse',
        'muscdn',
        'vigovideo',
      ],
    ),
    _SnapAnyPlatform(
      site: 'bilibili',
      label: '哔哩哔哩',
      hostPatterns: ['bilibili', 'b23'],
    ),
    _SnapAnyPlatform(
      site: 'pinterest',
      label: 'Pinterest',
      hostPatterns: ['pinterest', 'pin.it', 'pin'],
    ),
    _SnapAnyPlatform(
      site: 'vk',
      label: 'VK',
      hostPatterns: ['vk', 'vkvideo'],
    ),
    _SnapAnyPlatform(
      site: 'ok-ru',
      label: 'OK.ru',
      hostPatterns: ['ok.ru', 'ok'],
    ),
    _SnapAnyPlatform(
      site: 'dailymotion',
      label: 'Dailymotion',
      hostPatterns: ['dailymotion', 'dai.ly'],
    ),
    _SnapAnyPlatform(
      site: 'reddit',
      label: 'Reddit',
      hostPatterns: ['reddit', 'redd.it', 'redd'],
    ),
    _SnapAnyPlatform(
      site: 'suno',
      label: 'Suno',
      hostPatterns: ['suno'],
    ),
    _SnapAnyPlatform(
      site: 'threads',
      label: 'Threads',
      hostPatterns: ['threads'],
    ),
  ];

  final Dio _dio;

  static List<String> get supportedPlatformLabels =>
      _platforms.map((platform) => platform.label).toList(growable: false);

  bool canHandle(Uri uri) => _detectPlatform(uri) != null;

  _SnapAnyPlatform? _detectPlatform(Uri uri) {
    final host = uri.host.toLowerCase();
    for (final platform in _platforms) {
      if (platform.matches(host)) {
        return platform;
      }
    }
    return null;
  }

  Future<VideoExtractionResult> extract(String rawInput) async {
    final l10n = AppLocalizations.current;
    final uri = Uri.tryParse(rawInput.trim());
    if (uri == null || uri.scheme.isEmpty || uri.host.isEmpty) {
      throw VideoDownloadException(l10n.invalidVideoUrl);
    }

    final platform = _detectPlatform(uri);
    if (platform == null) {
      throw VideoDownloadException(l10n.snapAnyUnsupportedLink);
    }

    try {
      final payload = await _extractPayload(uri.toString());
      return _buildResult(
        sourceUrl: uri.toString(),
        platform: platform,
        payload: payload,
      );
    } on VideoDownloadException {
      rethrow;
    } on DioException catch (error) {
      throw VideoDownloadException(_mapDioError(error));
    } on TimeoutException {
      throw VideoDownloadException(
        l10n.timeoutMessage(
          l10n.platformName('snapany'),
          l10n.parserTimeoutDetail,
        ),
      );
    } on FormatException {
      throw VideoDownloadException(l10n.snapAnyFormatChanged);
    } catch (error) {
      throw VideoDownloadException(
        l10n.parseFailed(l10n.platformName('snapany'), error),
      );
    }
  }

  Future<Map<String, dynamic>> _extractPayload(String link) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final signature = md5
        .convert(utf8.encode('$link$_locale$timestamp$_signatureSecret'))
        .toString();

    final response = await _dio
        .post<dynamic>(
          '/v1/extract/post',
          data: <String, dynamic>{'link': link},
          options: Options(
            responseType: ResponseType.json,
            headers: <String, String>{
              'Accept-Language': _locale,
            }..addAll(<String, String>{
                'G-Timestamp': timestamp,
                'G-Footer': signature,
              }),
            validateStatus: (status) => status != null && status < 500,
          ),
        )
        .timeout(const Duration(seconds: 25));

    final payload = _asMap(response.data);
    if (payload == null) {
      throw VideoDownloadException(AppLocalizations.current.snapAnyNoResult);
    }

    if (response.statusCode == null ||
        response.statusCode! < 200 ||
        response.statusCode! >= 300) {
      throw VideoDownloadException(_readServerMessage(payload));
    }

    final medias = _asList(payload['medias']);
    if (medias.isEmpty) {
      throw VideoDownloadException(_readServerMessage(payload));
    }

    return payload;
  }

  VideoExtractionResult _buildResult({
    required String sourceUrl,
    required _SnapAnyPlatform platform,
    required Map<String, dynamic> payload,
  }) {
    final mediaMaps = _asList(payload['medias'])
        .map(_asMap)
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);

    if (mediaMaps.isEmpty) {
      throw VideoDownloadException(AppLocalizations.current.snapAnyNoMedia);
    }

    final l10n = AppLocalizations.current;
    final muxedOptions = <DownloadAsset>[];
    final audioOptions = <DownloadAsset>[];
    final videoOnlyOptions = <DownloadAsset>[];
    final imageOptions = <DownloadAsset>[];

    final addedVideoUrls = <String>{};
    final addedAudioUrls = <String>{};
    final addedImageUrls = <String>{};
    var imageIndex = 0;
    Duration? duration;
    Uri? previewThumbnail;
    Map<String, String>? previewThumbnailHeaders;
    final fallbackHeaders = _normalizeHeaders(payload['headers']);
    final platformHeaders = _buildPlatformHeaders(
      platform: platform,
      sourceUrl: sourceUrl,
    );

    for (final media in mediaMaps) {
      final mediaType = '${media['media_type'] ?? ''}'.trim().toLowerCase();
      final headers = _mergeHeaders(
        platformHeaders,
        _normalizeHeaders(media['headers']) ?? fallbackHeaders,
      );
      final resourceUrl = mediaType == 'image'
          ? _parseSecureUri(media['resource_url'])
          : _parseUri(media['resource_url']);
      final previewUrl = _parseSecureUri(media['preview_url']);

      if (previewUrl != null &&
          previewThumbnail == null &&
          (mediaType == 'video' || mediaType == 'audio')) {
        previewThumbnail = previewUrl;
        previewThumbnailHeaders = headers;
      }

      final durationSeconds = _asInt(media['duration']);
      if (duration == null && durationSeconds > 0) {
        duration = Duration(seconds: durationSeconds);
      }

      switch (mediaType) {
        case 'video':
          if (resourceUrl != null &&
              addedVideoUrls.add(resourceUrl.toString())) {
            final fileExtension =
                _fileExtensionForUrl(resourceUrl, fallback: 'mp4');
            final durationLabel = durationSeconds > 0 ? ' · ${durationSeconds}s' : '';
            muxedOptions.add(
              DownloadAsset(
                source: VideoSource.snapany,
                id: '${platform.site}-video-${muxedOptions.length}',
                title: l10n.videoTitle,
                subtitle:
                    '${_extensionLabel(fileExtension)} · ${l10n.directLinkDownload}$durationLabel',
                fileStem: 'video',
                fileExtension: fileExtension,
                kind: DownloadAssetKind.muxedVideo,
                sizeInBytes: 0,
                url: resourceUrl,
                headers: headers,
              ),
            );
          }
          break;
        case 'audio':
          if (resourceUrl != null &&
              addedAudioUrls.add(resourceUrl.toString())) {
            final fileExtension =
                _fileExtensionForUrl(resourceUrl, fallback: 'mp3');
            final durationLabel = durationSeconds > 0 ? ' · ${durationSeconds}s' : '';
            audioOptions.add(
              DownloadAsset(
                source: VideoSource.snapany,
                id: '${platform.site}-audio-${audioOptions.length}',
                title: l10n.audioTitle,
                subtitle:
                    '${_extensionLabel(fileExtension)} · ${l10n.directLinkDownload}$durationLabel',
                fileStem: 'audio',
                fileExtension: fileExtension,
                kind: DownloadAssetKind.audioOnly,
                sizeInBytes: 0,
                url: resourceUrl,
                headers: headers,
              ),
            );
          }
          break;
        case 'image':
          if (resourceUrl != null &&
              addedImageUrls.add(resourceUrl.toString())) {
            imageIndex += 1;
            final fileExtension =
                _fileExtensionForUrl(resourceUrl, fallback: 'jpg');
            imageOptions.add(
              DownloadAsset(
                source: VideoSource.snapany,
                id: '${platform.site}-image-$imageIndex',
                title: l10n.imageTitle(imageIndex),
                subtitle:
                    '${_extensionLabel(fileExtension)} · ${l10n.originalImage}',
                fileStem: 'image-$imageIndex',
                fileExtension: fileExtension,
                kind: DownloadAssetKind.image,
                sizeInBytes: 0,
                url: resourceUrl,
                headers: headers,
              ),
            );
          }
          break;
      }
    }

    if (previewThumbnail != null &&
        addedImageUrls.add(previewThumbnail.toString())) {
      imageOptions.insert(
        0,
        DownloadAsset(
          source: VideoSource.snapany,
          id: '${platform.site}-preview',
          title: l10n.coverTitle,
          subtitle:
              '${_extensionLabel(_fileExtensionForUrl(previewThumbnail, fallback: 'jpg'))} · ${l10n.previewImage}',
          fileStem: 'cover',
          fileExtension: _fileExtensionForUrl(previewThumbnail, fallback: 'jpg'),
          kind: DownloadAssetKind.thumbnail,
          sizeInBytes: 0,
          url: previewThumbnail,
          headers: previewThumbnailHeaders ?? platformHeaders,
        ),
      );
    }

    final title = _resolveTitle('${payload['text'] ?? ''}'.trim(), platform);
    final thumbnailUrl = imageOptions
            .firstWhere(
              (asset) => asset.url != null,
              orElse: () => DownloadAsset(
                source: VideoSource.snapany,
                id: '${platform.site}-fallback-thumbnail',
                title: l10n.coverTitle,
                subtitle: 'JPG · ${l10n.defaultCover}',
                fileStem: 'cover',
                fileExtension: 'jpg',
                kind: DownloadAssetKind.thumbnail,
                sizeInBytes: 0,
                url: Uri.parse('https://snapany.com/images/og.png'),
              ),
            )
            .url ??
        Uri.parse('https://snapany.com/images/og.png');
    final thumbnailHeaders = imageOptions
            .where((asset) => asset.url?.toString() == thumbnailUrl.toString())
            .map((asset) => asset.headers)
            .whereType<Map<String, String>>()
            .firstOrNull ??
        previewThumbnailHeaders;

    final quickActions = <DownloadAsset>[
      if (muxedOptions.isNotEmpty) muxedOptions.first,
      if (audioOptions.isNotEmpty) audioOptions.first,
      if (imageOptions.isNotEmpty) imageOptions.first,
    ];

    final totalAssets =
        muxedOptions.length + audioOptions.length + imageOptions.length;
    final platformLabel = l10n.platformName(platform.site);
    final warningParts = <String>[
      l10n.snapAnyWarning(platformLabel),
    ];

    if (_asInt(payload['overseas']) == 1) {
      warningParts.add(l10n.overseasNetworkWarning(platformLabel));
    }

    return VideoExtractionResult(
      source: VideoSource.snapany,
      platformLabel: platformLabel,
      sourceUrl: sourceUrl,
      videoId: '${payload['id'] ?? sourceUrl}',
      title: title,
      author: platformLabel,
      thumbnailUrl: thumbnailUrl,
      duration: duration,
      primaryMetricLabel: l10n.downloadItemsCount(totalAssets),
      description: trimDescription(
        '${payload['text'] ?? ''}'.trim().isEmpty
            ? l10n.parseResultTitle(platformLabel)
            : '${payload['text']}'.trim(),
      ),
      quickActions: quickActions,
      muxedOptions: muxedOptions,
      audioOptions: audioOptions,
      videoOnlyOptions: videoOnlyOptions,
      imageOptions: imageOptions,
      thumbnailHeaders: thumbnailHeaders,
      warning: warningParts.join(' '),
    );
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

  Uri? _parseUri(Object? value) {
    final raw = '$value'.trim();
    if (raw.isEmpty) {
      return null;
    }
    return Uri.tryParse(raw);
  }

  Uri? _parseSecureUri(Object? value) {
    final uri = _parseUri(value);
    if (uri == null) {
      return null;
    }

    return preferSecureUri(uri);
  }

  Map<String, String>? _normalizeHeaders(Object? value) {
    final map = _asMap(value);
    if (map == null || map.isEmpty) {
      return null;
    }

    return map.map((key, value) => MapEntry(key, '$value'));
  }

  Map<String, String> _buildPlatformHeaders({
    required _SnapAnyPlatform platform,
    required String sourceUrl,
  }) {
    final sourceUri = Uri.tryParse(sourceUrl);

    return <String, String>{
      'User-Agent': _browserUserAgent,
      'Referer': _defaultRefererFor(platform, sourceUri),
    };
  }

  String _defaultRefererFor(_SnapAnyPlatform platform, Uri? sourceUri) {
    if (platform.site == 'bilibili') {
      return 'https://www.bilibili.com/';
    }

    if (sourceUri == null || sourceUri.scheme.isEmpty || sourceUri.host.isEmpty) {
      return 'https://snapany.com/';
    }

    return sourceUri.replace(path: '/', query: '', fragment: '').toString();
  }

  Map<String, String>? _mergeHeaders(
    Map<String, String>? base,
    Map<String, String>? override,
  ) {
    if ((base == null || base.isEmpty) && (override == null || override.isEmpty)) {
      return null;
    }

    return <String, String>{
      ...?base,
      ...?override,
    };
  }

  String _readServerMessage(Map<String, dynamic> payload) {
    final l10n = AppLocalizations.current;
    final message = '${payload['message'] ?? ''}'.trim();
    if (message.isNotEmpty) {
      if (message.contains('操作太频繁')) {
        return l10n.snapAnyRateLimited;
      }
      return message;
    }
    return l10n.snapAnyNoResult;
  }

  String _mapDioError(DioException error) {
    final l10n = AppLocalizations.current;
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return l10n.timeoutMessage(
        l10n.platformName('snapany'),
        l10n.parserTimeoutDetail,
      );
    }

    if (error.error is SocketException) {
      return l10n.networkUnavailable(
        l10n.platformName('snapany'),
        l10n.parserNetworkDetail,
      );
    }

    if (error.error is HandshakeException) {
      return l10n.handshakeFailed(
        l10n.platformName('snapany'),
        l10n.parserHandshakeDetail,
      );
    }

    final statusCode = error.response?.statusCode;
    if (statusCode == 401 || statusCode == 402 || statusCode == 429) {
      return l10n.requestRejected(
        l10n.platformName('snapany'),
        l10n.snapAnyRetryLaterDetail,
      );
    }

    return l10n.requestFailed(
      l10n.platformName('snapany'),
      error.message ?? error.type.name,
    );
  }

  String _resolveTitle(String rawText, _SnapAnyPlatform platform) {
    final l10n = AppLocalizations.current;
    final platformLabel = l10n.platformName(platform.site);
    final lines = rawText
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((line) => line.isNotEmpty);
    final firstLine = lines.isEmpty ? '' : lines.first;
    final title = firstLine.isEmpty ? l10n.contentTitle(platformLabel) : firstLine;
    return truncateUtf8(title, 96);
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

  void dispose() {
    _dio.close(force: true);
  }
}

class _SnapAnyPlatform {
  const _SnapAnyPlatform({
    required this.site,
    required this.label,
    required this.hostPatterns,
  });

  final String site;
  final String label;
  final List<String> hostPatterns;

  bool matches(String host) {
    for (final pattern in hostPatterns) {
      final normalizedPattern = pattern.toLowerCase();
      if (host == normalizedPattern || host.endsWith('.$normalizedPattern')) {
        return true;
      }

      if (!normalizedPattern.contains('.') &&
          host.split('.').contains(normalizedPattern)) {
        return true;
      }
    }

    return false;
  }
}
