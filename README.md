# Tube Fetch

一个用 Flutter 实现的 iOS / Android 视频下载器原型，目标是复刻 [youtube.iiilab.com](https://youtube.iiilab.com/) 这类工具站的核心闭环，但不把网页直接嵌进 App。

## 当前支持的平台

- YouTube
- 抖音
- TikTok
- 哔哩哔哩
- 微博 / 秒拍 / 绿洲
- Twitter / X
- Instagram
- Facebook
- Pinterest
- VK
- OK.ru
- Dailymotion
- Reddit
- Suno
- Threads
- 最右
- 微视
- 全民K歌
- 全民小视频
- 陌陌
- 美拍
- Vimeo
- Tumblr
- 云音乐
- 趣头条
- 映客
- 小影 / VivaVideo
- 梨视频

说明：

- 上面这批平台是按 [iiilab 首页](https://youtube.iiilab.com/) 当前公开支持的平台，以及它前端当前跳转到 [SnapAny](https://snapany.com/zh) 的那批平台做的对齐。
- `抖音` 仍走本地分享页解析，不依赖 `iiilab`。
- `YouTube` 仍优先走本地流清单解析，稳定性比单纯转调网页接口更好。
- `哔哩哔哩` 现在优先走移动页 SSR 直连解析，不再依赖 `SnapAny`。
- `兽音译者` 不属于视频下载平台，这个仓库也没有接。

## 我对目标站点的分析

2026-04-21 对 `https://youtube.iiilab.com/` 做了首页和前端 bundle 分析，确认现在这批站点的核心链路是：

1. 首页明确列出当前支持的平台导航。
2. 前端会先根据输入链接 host 识别 `site`。
3. 前端调用 `POST /api/web/extract`。
4. 请求头里带：
   - `G-Timestamp`
   - `G-Footer`
5. `G-Footer` 是前端 bundle 里公开常量拼接后做 `MD5(url + site + timestamp + secret)` 算出来的。
6. 接口返回 `text`、`medias`、`formats`、`preview_url`、`resource_url`、`headers` 等字段，前端再渲染下载按钮。

另外也分析了 `iiilab` 当前会跳转过去的 `SnapAny` 前端链路，确认它的核心流程是：

1. 前端根据输入链接 host 识别平台。
2. 前端调用 `POST https://api.snapany.com/v1/extract/post`。
3. 请求头里带：
   - `G-Timestamp`
   - `G-Footer`
4. `G-Footer` 是前端 bundle 里的公开常量参与拼接后做 `MD5(link + locale + timestamp + secret)` 算出来的。
5. 接口同样返回 `medias / preview_url / resource_url` 这类字段，前端再渲染下载按钮。

仓库里对应实现：

- [lib/services/video_download_service.dart](/Users/zuolizhen/Documents/my_github/video_download/lib/services/video_download_service.dart)
- [lib/services/iiilab_download_service.dart](/Users/zuolizhen/Documents/my_github/video_download/lib/services/iiilab_download_service.dart)
- [lib/services/snapany_download_service.dart](/Users/zuolizhen/Documents/my_github/video_download/lib/services/snapany_download_service.dart)
- [lib/services/bilibili_download_service.dart](/Users/zuolizhen/Documents/my_github/video_download/lib/services/bilibili_download_service.dart)
- [lib/services/youtube_download_service.dart](/Users/zuolizhen/Documents/my_github/video_download/lib/services/youtube_download_service.dart)
- [lib/services/douyin_download_service.dart](/Users/zuolizhen/Documents/my_github/video_download/lib/services/douyin_download_service.dart)
- [lib/models/download_models.dart](/Users/zuolizhen/Documents/my_github/video_download/lib/models/download_models.dart)
- [lib/home_page.dart](/Users/zuolizhen/Documents/my_github/video_download/lib/home_page.dart)

## 当前实现方案

- `YouTube`
  - 用 `youtube_explode_dart` 直接拿视频信息和流清单
  - 支持音视频合流、独立音频、高清视频无音轨流
- `抖音`
  - 走分享页 SSR 数据解析
  - 支持无水印 MP4、带水印 MP4、封面图
- `哔哩哔哩`
  - 走移动页 `window.__INITIAL_STATE__` 直连解析
  - 支持带音轨 MP4 和封面图 / 首帧图
- `iiilab` 同站系平台
  - 新增 `IiilabDownloadService`
  - 直接复刻其前端 `extract` 调用流程
  - 解析 `medias / formats / headers`
  - 把返回的请求头附着到下载项，兼容 Vimeo 这类带 Cookie / UA 要求的直链
- `SnapAny` 跳转系平台
  - 新增 `SnapAnyDownloadService`
  - 直接复刻其前端 `extract` 调用流程
  - 当前补齐 `TikTok / Pinterest / VK / OK.ru / Dailymotion / Reddit / Suno / Threads`
  - 解析 `medias / headers`
  - 返回视频、音频、图片 / 封面直链下载项

UI 侧统一支持：

- 粘贴链接自动识别平台
- 展示视频、音频、图片 / 封面下载项
- 下载到本地
- 保存到系统相册
- 通过系统分享面板分享文件

## 技术栈

- `youtube_explode_dart`
- `dio`
- `crypto`
- `path_provider`
- `open_filex`
- `gal`
- `share_plus`

## 运行方式

```bash
flutter pub get
flutter run
```

## 已知限制

- `iiilab` 这批平台的直链通常有时效，解析后建议尽快下载。
- `iiilab / SnapAny` 这批平台返回字段不完全一致，所以通用解析结果通常拿不到作者、时长这类完整元数据。
- 海外平台资源仍然受设备当前网络环境影响。
- `SnapAny` 这批平台偶尔会触发频率限制，短时间重复解析同站点时可能需要稍后再试；`哔哩哔哩` 已改为本地直连解析，不走这条限流链路。
- `YouTube` 的 1080p / 4K 常见仍是无音轨视频流，若要直接播放，需要再和音频合并。
- `抖音` 当前还是基于分享页解析，只支持视频页，不支持图文、直播、合集。
- 现在没有做后台下载恢复、历史记录、本地媒体库管理。
