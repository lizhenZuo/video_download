# Tube Fetch

一个用 Flutter 实现的 iOS / Android 视频下载器原型，目前支持 YouTube 和抖音，目标是复刻 [youtube.iiilab.com](https://youtube.iiilab.com/) 这类工具站的核心闭环，而不是把网页直接嵌进 App。

## 我对目标站点的分析

2026-04-20 对 `https://youtube.iiilab.com/` 做了页面和前端 bundle 分析，确认它的核心功能链路是：

1. 用户粘贴 YouTube 链接。
2. 前端先校验并归一化链接。
3. 前端调用 `/api/web/extract` 解析接口。
4. 接口返回 `medias`、`formats`、`preview_url`、`resource_url` 等字段。
5. 页面把结果渲染成：
   - 视频下载
   - 音频下载
   - 封面下载
   - 多分辨率下载选项
   - 移动端下载提示

这个仓库没有去调用它的私有签名接口，而是改成了 App 端自己完成解析，原因很明确：

- 站点接口是私有实现，签名和 header 规则随时可能变。
- 直接复用第三方私有接口，维护成本高，也不稳。
- Flutter 原生实现更容易扩展成你自己的产品能力。

## 当前实现的能力

- 粘贴 YouTube 或抖音视频链接
- 自动识别来源平台并走对应解析链路
- 拉取标题、作者、时长、封面和核心互动指标
- YouTube:
  - 展示可直接播放的视频流
  - 展示独立音频流
  - 展示高分辨率无音轨视频流
- 抖音:
  - 解析分享页 SSR 数据
  - 提供无水印 MP4、带水印 MP4、封面图下载
- 下载到本地
- 保存到系统相册
- 通过系统分享面板分享文件
- iOS 开启 Files 可见性和相册权限说明
- Android 增加网络权限

## 技术方案

- `youtube_explode_dart`
  用来获取 YouTube 视频元数据和可下载流清单。
- `dio`
  用来请求抖音分享页、解析 SSR 数据，以及下载普通 HTTP 文件。
- `path_provider`
  负责定位下载目录。
- `open_filex`
  Android 上下载完成后交给系统打开文件。
- `gal`
  保存视频或图片到系统相册。
- `share_plus`
  调起系统分享面板。

代码结构：

- [lib/main.dart](/Users/zuolizhen/Documents/my_github/video_download/lib/main.dart)
- [lib/home_page.dart](/Users/zuolizhen/Documents/my_github/video_download/lib/home_page.dart)
- [lib/models/download_models.dart](/Users/zuolizhen/Documents/my_github/video_download/lib/models/download_models.dart)
- [lib/services/video_download_service.dart](/Users/zuolizhen/Documents/my_github/video_download/lib/services/video_download_service.dart)
- [lib/services/douyin_download_service.dart](/Users/zuolizhen/Documents/my_github/video_download/lib/services/douyin_download_service.dart)
- [lib/services/youtube_download_service.dart](/Users/zuolizhen/Documents/my_github/video_download/lib/services/youtube_download_service.dart)

## 运行方式

```bash
flutter pub get
flutter run
```

## 已知限制

- 如果设备当前网络无法访问 YouTube，解析会失败。
- 如果设备当前网络无法访问抖音分享页，抖音解析也会失败。
- 1080p / 4K 常见为无音轨视频流，下载后如果要直接播放，需要再和音频合并。
- 抖音当前是基于分享页解析，能拿到直连 MP4 和封面，但不提供独立音频和更多清晰度流。
- 现在的包版本受当前 Flutter SDK 约束，`youtube_explode_webview` 没有接入。
- `applicationId` 和 iOS bundle id 仍是模板默认值，准备上架前需要换成你自己的。

## 下一步建议

如果你要把它做成可上线产品，下一步应该补这几块：

1. 自有后端代理和任务队列。
2. 视频流与音频流自动合并。
3. 下载任务持久化与后台恢复。
4. 历史记录、本地文件管理和分享。
5. 你自己的包名、图标、隐私说明和上架合规处理。
