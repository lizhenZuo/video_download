import 'package:youtube_explode_dart/youtube_explode_dart.dart';

enum DownloadAssetKind {
  muxedVideo,
  audioOnly,
  videoOnly,
  thumbnail,
}

class DownloadAsset {
  const DownloadAsset({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.fileStem,
    required this.fileExtension,
    required this.kind,
    required this.sizeInBytes,
    this.streamInfo,
    this.url,
    this.requiresMuxing = false,
  });

  final String id;
  final String title;
  final String subtitle;
  final String fileStem;
  final String fileExtension;
  final DownloadAssetKind kind;
  final int sizeInBytes;
  final StreamInfo? streamInfo;
  final Uri? url;
  final bool requiresMuxing;
}

class VideoExtractionResult {
  const VideoExtractionResult({
    required this.sourceUrl,
    required this.videoId,
    required this.title,
    required this.author,
    required this.thumbnailUrl,
    required this.duration,
    required this.viewCount,
    required this.description,
    required this.quickActions,
    required this.muxedOptions,
    required this.audioOptions,
    required this.videoOnlyOptions,
    this.warning,
  });

  final String sourceUrl;
  final String videoId;
  final String title;
  final String author;
  final Uri thumbnailUrl;
  final Duration? duration;
  final int viewCount;
  final String description;
  final List<DownloadAsset> quickActions;
  final List<DownloadAsset> muxedOptions;
  final List<DownloadAsset> audioOptions;
  final List<DownloadAsset> videoOnlyOptions;
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
        DownloadAssetKind.thumbnail => true,
        DownloadAssetKind.audioOnly => false,
      };

  bool get isVideo => switch (asset.kind) {
        DownloadAssetKind.muxedVideo => true,
        DownloadAssetKind.videoOnly => true,
        DownloadAssetKind.audioOnly => false,
        DownloadAssetKind.thumbnail => false,
      };
}
