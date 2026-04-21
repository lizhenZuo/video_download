import 'package:youtube_explode_dart/youtube_explode_dart.dart';

enum VideoSource {
  youtube,
  douyin,
  bilibili,
  iiilab,
  snapany,
}

extension VideoSourceX on VideoSource {
  String get displayName => switch (this) {
        VideoSource.youtube => 'YouTube',
        VideoSource.douyin => '抖音',
        VideoSource.bilibili => '哔哩哔哩',
        VideoSource.iiilab => 'iiilab',
        VideoSource.snapany => 'SnapAny',
      };

  String get fallbackFilePrefix => switch (this) {
        VideoSource.youtube => 'youtube-media',
        VideoSource.douyin => 'douyin-media',
        VideoSource.bilibili => 'bilibili-media',
        VideoSource.iiilab => 'iiilab-media',
        VideoSource.snapany => 'snapany-media',
      };
}

enum DownloadAssetKind {
  muxedVideo,
  audioOnly,
  videoOnly,
  image,
  thumbnail,
}

class DownloadAsset {
  const DownloadAsset({
    required this.source,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.fileStem,
    required this.fileExtension,
    required this.kind,
    required this.sizeInBytes,
    this.streamInfo,
    this.url,
    this.headers,
    this.requiresMuxing = false,
  });

  final VideoSource source;
  final String id;
  final String title;
  final String subtitle;
  final String fileStem;
  final String fileExtension;
  final DownloadAssetKind kind;
  final int sizeInBytes;
  final StreamInfo? streamInfo;
  final Uri? url;
  final Map<String, String>? headers;
  final bool requiresMuxing;
}

class VideoExtractionResult {
  const VideoExtractionResult({
    required this.source,
    required this.platformLabel,
    required this.sourceUrl,
    required this.videoId,
    required this.title,
    required this.author,
    required this.thumbnailUrl,
    required this.duration,
    required this.primaryMetricLabel,
    required this.description,
    required this.quickActions,
    required this.muxedOptions,
    required this.audioOptions,
    required this.videoOnlyOptions,
    required this.imageOptions,
    this.thumbnailHeaders,
    this.warning,
  });

  final VideoSource source;
  final String platformLabel;
  final String sourceUrl;
  final String videoId;
  final String title;
  final String author;
  final Uri thumbnailUrl;
  final Duration? duration;
  final String primaryMetricLabel;
  final String description;
  final List<DownloadAsset> quickActions;
  final List<DownloadAsset> muxedOptions;
  final List<DownloadAsset> audioOptions;
  final List<DownloadAsset> videoOnlyOptions;
  final List<DownloadAsset> imageOptions;
  final Map<String, String>? thumbnailHeaders;
  final String? warning;
}

class DownloadReceipt {
  const DownloadReceipt({
    required this.filePath,
    required this.fileName,
    required this.asset,
  });

  final String filePath;
  final String fileName;
  final DownloadAsset asset;

  bool get canSaveToGallery => switch (asset.kind) {
        DownloadAssetKind.muxedVideo => true,
        DownloadAssetKind.videoOnly => true,
        DownloadAssetKind.image => true,
        DownloadAssetKind.thumbnail => true,
        DownloadAssetKind.audioOnly => false,
      };

  bool get isVideo => switch (asset.kind) {
        DownloadAssetKind.muxedVideo => true,
        DownloadAssetKind.videoOnly => true,
        DownloadAssetKind.audioOnly => false,
        DownloadAssetKind.image => false,
        DownloadAssetKind.thumbnail => false,
      };
}
