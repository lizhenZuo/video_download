import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import '../l10n/app_localizations.dart';
import '../models/download_models.dart';
import 'download_support.dart';

class IiilabDownloadService {
  IiilabDownloadService()
      : _dio = Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 20),
            receiveTimeout: const Duration(seconds: 30),
            contentType: Headers.jsonContentType,
            headers: const {
              'Accept': 'application/json, text/plain, */*',
              'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/139.0.0.0 Safari/537.36',
            },
          ),
        );

  final Dio _dio;

  static const List<_IiilabPlatform> _platforms = [
    _IiilabPlatform(
      site: 'weibo',
      label: '微博 / 秒拍 / 绿洲',
      hostPatterns: ['weibo', 'weico', 'miaopai', 'xiaokaxiu', 'yixia'],
    ),
    _IiilabPlatform(
      site: 'youtube',
      label: 'YouTube',
      hostPatterns: ['youtube', 'youtu.be', 'youtu'],
    ),
    _IiilabPlatform(
      site: 'twitter',
      label: 'Twitter / X',
      hostPatterns: ['twitter', 'x.com'],
    ),
    _IiilabPlatform(
      site: 'instagram',
      label: 'Instagram',
      hostPatterns: ['instagram'],
    ),
    _IiilabPlatform(
      site: 'facebook',
      label: 'Facebook',
      hostPatterns: ['facebook', 'fb.watch', 'fb'],
    ),
    _IiilabPlatform(
      site: 'zuiyou',
      label: '最右',
      hostPatterns: ['izuiyou', 'zuiyou'],
    ),
    _IiilabPlatform(
      site: 'weishi',
      label: '微视',
      hostPatterns: ['weishi.qq', 'qzone.qq'],
    ),
    _IiilabPlatform(
      site: 'kg',
      label: '全民K歌',
      hostPatterns: ['kg.qq', 'kg1.qq', 'kg2.qq', 'kg3.qq', 'kg4.qq'],
    ),
    _IiilabPlatform(
      site: 'quanmin',
      label: '全民小视频',
      hostPatterns: ['haokan.baidu', 'hao222'],
    ),
    _IiilabPlatform(
      site: 'momo',
      label: '陌陌',
      hostPatterns: ['immomo', 'momocdn', 'momo'],
    ),
    _IiilabPlatform(
      site: 'meipai',
      label: '美拍',
      hostPatterns: ['meipai'],
    ),
    _IiilabPlatform(
      site: 'vimeo',
      label: 'Vimeo',
      hostPatterns: ['vimeo'],
    ),
    _IiilabPlatform(
      site: 'tumblr',
      label: 'Tumblr',
      hostPatterns: ['tumblr', 'luisonte'],
    ),
    _IiilabPlatform(
      site: 'yinyue',
      label: '云音乐',
      hostPatterns: ['music.163', '163.com', '163.fm', '163cn'],
    ),
    _IiilabPlatform(
      site: 'quduopai',
      label: '趣头条',
      hostPatterns: ['quduopai'],
    ),
    _IiilabPlatform(
      site: 'inke',
      label: '映客',
      hostPatterns: ['inke'],
    ),
    _IiilabPlatform(
      site: 'xiaoying',
      label: '小影 / VivaVideo',
      hostPatterns: ['xiaoying', 'vivavideo'],
    ),
    _IiilabPlatform(
      site: 'pearvideo',
      label: '梨视频',
      hostPatterns: ['pearvideo'],
    ),
  ];

  static final String _signatureSecret = ['SlNuSEtRZlA=', 'MUlseklRenM=']
      .map((value) => utf8.decode(base64Decode(value)))
      .join();

  static List<String> get supportedPlatformLabels =>
      _platforms.map((platform) => platform.label).toList(growable: false);

  bool canHandle(Uri uri) => _detectPlatform(uri) != null;

  _IiilabPlatform? _detectPlatform(Uri uri) {
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
      throw VideoDownloadException(l10n.iiilabUnsupportedLink);
    }

    try {
      final payload = await _extractPayload(uri.toString(), platform);
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
        l10n.timeoutMessage(l10n.platformName('iiilab'), l10n.parserTimeoutDetail),
      );
    } on FormatException {
      throw VideoDownloadException(l10n.parseServiceFormatChanged);
    } catch (error) {
      throw VideoDownloadException(
        l10n.parseFailed(l10n.platformName('iiilab'), error),
      );
    }
  }

  Future<Map<String, dynamic>> _extractPayload(
    String url,
    _IiilabPlatform platform,
  ) async {
    final timestamp =
        (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
    final signature = md5
        .convert(utf8.encode('$url${platform.site}$timestamp$_signatureSecret'))
        .toString();

    final response = await _dio
        .postUri<dynamic>(
          Uri.parse('https://${platform.site}.iiilab.com/api/web/extract'),
          data: <String, dynamic>{
            'url': url,
            'site': platform.site,
          },
          options: Options(
            responseType: ResponseType.json,
            headers: <String, String>{
              'G-Timestamp': timestamp,
              'G-Footer': signature,
            },
            validateStatus: (status) => status != null && status < 500,
          ),
        )
        .timeout(const Duration(seconds: 25));

    final payload = _asMap(response.data);
    if (payload == null) {
      throw VideoDownloadException(AppLocalizations.current.parseServiceNoResult);
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
    required _IiilabPlatform platform,
    required Map<String, dynamic> payload,
  }) {
    final mediaMaps = _expandMediaList(_asList(payload['medias']));
    if (mediaMaps.isEmpty) {
      throw VideoDownloadException(AppLocalizations.current.parseServiceNoMedia);
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
    Map<String, String>? thumbnailHeaders;

    for (final media in mediaMaps) {
      final mediaType = '${media['media_type'] ?? ''}'.trim().toLowerCase();
      final headers = _normalizeHeaders(media['headers']);
      final previewUrl = _parseSecureUri(media['preview_url']);
      final resourceUrl = _parseUri(media['resource_url']);

      if (previewUrl != null && addedImageUrls.add(previewUrl.toString())) {
        thumbnailHeaders ??= headers;
        imageOptions.add(
          DownloadAsset(
            source: VideoSource.iiilab,
            id: '${platform.site}-preview-${imageOptions.length}',
            title: l10n.coverTitle,
            subtitle:
                '${_extensionLabel(_fileExtensionForUrl(previewUrl, fallback: 'jpg'))} · ${l10n.previewImage}',
            fileStem: 'cover',
            fileExtension: _fileExtensionForUrl(previewUrl, fallback: 'jpg'),
            kind: DownloadAssetKind.thumbnail,
            sizeInBytes: 0,
            url: previewUrl,
            headers: headers,
          ),
        );
      }

      switch (mediaType) {
        case 'video':
          final formats = _asList(media['formats']);
          if (formats.isNotEmpty) {
            for (final formatValue in formats) {
              final format = _asMap(formatValue);
              if (format == null) {
                continue;
              }

              final videoUrl = _parseUri(format['video_url']);
              if (videoUrl == null ||
                  !addedVideoUrls.add(videoUrl.toString())) {
                continue;
              }

              final separate = _asInt(format['separate']) == 1;
              final qualityNote = _qualityLabel(format);
              final fileExtension = _fileExtensionForFormat(format, videoUrl);
              final asset = DownloadAsset(
                source: VideoSource.iiilab,
                id:
                    '${platform.site}-${separate ? 'video-only' : 'video'}-${qualityNote.toLowerCase()}-${formats.length}-${addedVideoUrls.length}',
                title: l10n.videoQualityTitle(qualityNote),
                subtitle:
                    '${_extensionLabel(fileExtension)} · ${separate ? '${l10n.videoOnly} ${l10n.directLink}' : '${l10n.withAudioTrack} ${l10n.directLink}'}',
                fileStem:
                    'video-${_slugifyQuality(qualityNote)}${separate ? '-silent' : ''}',
                fileExtension: fileExtension,
                kind: separate
                    ? DownloadAssetKind.videoOnly
                    : DownloadAssetKind.muxedVideo,
                sizeInBytes: _asInt(format['video_size']),
                url: videoUrl,
                headers: headers,
                requiresMuxing: separate,
              );

              if (separate) {
                videoOnlyOptions.add(asset);
              } else {
                muxedOptions.add(asset);
              }

              final audioUrl = _parseUri(format['audio_url']);
              if (audioUrl != null && addedAudioUrls.add(audioUrl.toString())) {
                final audioExt =
                    _fileExtensionForUrl(audioUrl, fallback: 'm4a');
                audioOptions.add(
                  DownloadAsset(
                    source: VideoSource.iiilab,
                    id: '${platform.site}-audio-${audioOptions.length}',
                    title: l10n.audioTitle,
                    subtitle:
                        '${_extensionLabel(audioExt)} · ${l10n.separatedAudioTrack}',
                    fileStem: 'audio',
                    fileExtension: audioExt,
                    kind: DownloadAssetKind.audioOnly,
                    sizeInBytes: _asInt(format['audio_size']),
                    url: audioUrl,
                    headers: headers,
                  ),
                );
              }
            }
          } else if (resourceUrl != null &&
              addedVideoUrls.add(resourceUrl.toString())) {
            final fileExtension =
                _fileExtensionForUrl(resourceUrl, fallback: 'mp4');
            muxedOptions.add(
              DownloadAsset(
                source: VideoSource.iiilab,
                id: '${platform.site}-video-default',
                title: l10n.directVideoTitle,
                subtitle:
                    '${_extensionLabel(fileExtension)} · ${l10n.defaultDownloadItem}',
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
          if (resourceUrl != null && addedAudioUrls.add(resourceUrl.toString())) {
            final fileExtension =
                _fileExtensionForUrl(resourceUrl, fallback: 'mp3');
            audioOptions.add(
              DownloadAsset(
                source: VideoSource.iiilab,
                id: '${platform.site}-audio-${audioOptions.length}',
                title: l10n.audioTitle,
                subtitle:
                    '${_extensionLabel(fileExtension)} · ${l10n.directLink}',
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
          final secureImageUrl = resourceUrl == null
              ? null
              : preferSecureUri(resourceUrl);
          if (secureImageUrl != null &&
              addedImageUrls.add(secureImageUrl.toString())) {
            imageIndex += 1;
            final fileExtension =
                _fileExtensionForUrl(secureImageUrl, fallback: 'jpg');
            thumbnailHeaders ??= headers;
            imageOptions.add(
              DownloadAsset(
                source: VideoSource.iiilab,
                id: '${platform.site}-image-$imageIndex',
                title: l10n.imageTitle(imageIndex),
                subtitle:
                    '${_extensionLabel(fileExtension)} · ${l10n.originalImage}',
                fileStem: 'image-$imageIndex',
                fileExtension: fileExtension,
                kind: DownloadAssetKind.image,
                sizeInBytes: 0,
                url: secureImageUrl,
                headers: headers,
              ),
            );
          }
          break;
      }
    }

    final rawText = '${payload['text'] ?? ''}'.trim();
    final platformLabel = l10n.platformName(platform.site);
    final title = _resolveTitle(rawText, platform);
    final thumbnailUrl = imageOptions
            .map((asset) => asset.url)
            .whereType<Uri>()
            .firstOrNull ??
        Uri.parse('https://${platform.site}.iiilab.com/images/og.png');

    final quickActions = _buildQuickActions(
      muxedOptions: muxedOptions,
      audioOptions: audioOptions,
      videoOnlyOptions: videoOnlyOptions,
      imageOptions: imageOptions,
    );

    final totalAssets = muxedOptions.length +
        audioOptions.length +
        videoOnlyOptions.length +
        imageOptions.length;

    final warningParts = <String>[
      l10n.iiilabWarning(l10n.platformName('iiilab')),
    ];

    if (_asInt(payload['overseas']) == 1) {
      warningParts.add(l10n.overseasNetworkWarning(platformLabel));
    }

    if (videoOnlyOptions.any((asset) => asset.requiresMuxing)) {
      warningParts.add(l10n.muxingWarning);
    }

    return VideoExtractionResult(
      source: VideoSource.iiilab,
      platformLabel: platformLabel,
      sourceUrl: sourceUrl,
      videoId: sourceUrl,
      title: title,
      author: platformLabel,
      thumbnailUrl: thumbnailUrl,
      duration: null,
      primaryMetricLabel: l10n.downloadItemsCount(totalAssets),
      description: trimDescription(
        rawText.isEmpty ? l10n.parseResultTitle(platformLabel) : rawText,
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

  List<DownloadAsset> _buildQuickActions({
    required List<DownloadAsset> muxedOptions,
    required List<DownloadAsset> audioOptions,
    required List<DownloadAsset> videoOnlyOptions,
    required List<DownloadAsset> imageOptions,
  }) {
    final quickActions = <DownloadAsset>[];

    final primaryVideo =
        muxedOptions.firstOrNull ?? videoOnlyOptions.firstOrNull;
    if (primaryVideo != null) {
      quickActions.add(primaryVideo);
    }

    if (audioOptions.isNotEmpty) {
      quickActions.add(audioOptions.first);
    }

    for (final asset in imageOptions) {
      if (quickActions.length >= 4) {
        break;
      }
      quickActions.add(asset);
    }

    if (quickActions.isEmpty) {
      quickActions.addAll(
        [
          ...muxedOptions,
          ...audioOptions,
          ...videoOnlyOptions,
          ...imageOptions,
        ].take(4),
      );
    }

    return quickActions;
  }

  List<Map<String, dynamic>> _expandMediaList(List<dynamic> mediaList) {
    final medias = mediaList
        .map(_asMap)
        .whereType<Map<String, dynamic>>()
        .toList(growable: true);

    if (medias.isEmpty) {
      return const [];
    }

    final firstFormats = _asList(medias.first['formats']);
    for (final formatValue in firstFormats) {
      final format = _asMap(formatValue);
      if (format == null || _asInt(format['separate']) != 1) {
        continue;
      }

      final audioUrl = _parseUri(format['audio_url']);
      if (audioUrl == null) {
        continue;
      }

      medias.add(
        <String, dynamic>{
          'media_type': 'audio',
          'resource_url': audioUrl.toString(),
          'headers': medias.first['headers'],
        },
      );
      break;
    }

    return medias;
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

    return map.map(
      (key, value) => MapEntry(key, '$value'),
    );
  }

  String _readServerMessage(Map<String, dynamic> payload) {
    final l10n = AppLocalizations.current;
    final message = '${payload['message'] ?? ''}'.trim();
    if (message.isNotEmpty) {
      return message;
    }

    final code = '${payload['code'] ?? ''}'.trim();
    if (code == 'ShowSponsorAds') {
      return l10n.parseServiceExtraLimit;
    }

    return l10n.parseServiceNoResult;
  }

  String _mapDioError(DioException error) {
    final l10n = AppLocalizations.current;
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return l10n.timeoutMessage(
        l10n.platformName('iiilab'),
        l10n.parserTimeoutDetail,
      );
    }

    if (error.error is SocketException) {
      return l10n.networkUnavailable(
        l10n.platformName('iiilab'),
        l10n.parserNetworkDetail,
      );
    }

    if (error.error is HandshakeException) {
      return l10n.handshakeFailed(
        l10n.platformName('iiilab'),
        l10n.parserHandshakeDetail,
      );
    }

    final statusCode = error.response?.statusCode;
    if (statusCode == 403 || statusCode == 429) {
      return l10n.requestRejected(
        l10n.platformName('iiilab'),
        l10n.retryLaterDetail,
      );
    }

    return l10n.requestFailed(
      l10n.platformName('iiilab'),
      error.message ?? error.type.name,
    );
  }

  String _resolveTitle(String rawText, _IiilabPlatform platform) {
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

  String _qualityLabel(Map<String, dynamic> format) {
    final note = '${format['quality_note'] ?? ''}'.trim();
    if (note.isNotEmpty) {
      return note;
    }

    final quality = _asInt(format['quality']);
    if (quality > 0) {
      return '${quality}p';
    }

    return AppLocalizations.current.originalQuality;
  }

  String _slugifyQuality(String input) {
    final normalized = input.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    return normalized.replaceAll(RegExp(r'^-+|-+$'), '').trim().isEmpty
        ? 'default'
        : normalized.replaceAll(RegExp(r'^-+|-+$'), '');
  }

  String _fileExtensionForFormat(Map<String, dynamic> format, Uri url) {
    final fromField = '${format['video_ext'] ?? ''}'.trim().toLowerCase();
    if (fromField.isNotEmpty) {
      return fromField;
    }
    return _fileExtensionForUrl(url, fallback: 'mp4');
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

class _IiilabPlatform {
  const _IiilabPlatform({
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
      if (host == normalizedPattern ||
          host.endsWith('.$normalizedPattern') ||
          host.contains(normalizedPattern) ||
          host.split('.').contains(normalizedPattern)) {
        return true;
      }
    }

    return false;
  }
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
