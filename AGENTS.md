# Simple Live 项目指南

本文件面向 AI 编程代理。如果这是你第一次接触本项目，请先阅读本文件，再查看具体代码。

## 项目概述

Simple Live 是一个聚合多个国内直播平台（虎牙、斗鱼、哔哩哔哩、抖音）的直播观看与弹幕工具。

项目采用 Dart / Flutter 编写，使用单仓库多包结构：

- `simple_live_core`：核心库，封装各直播平台的数据抓取、直播间详情获取、清晰度解析、直链解析、弹幕连接。
- `simple_live_app`：基于 `simple_live_core` 的 Flutter 移动/桌面客户端（Android、iOS、Windows、macOS、Linux）。
- `simple_live_tv_app`：基于 `simple_live_core` 的 Flutter Android TV 客户端。
- `simple_live_console`：基于 `simple_live_core` 的命令行工具，用于测试与获取直链/弹幕。

> 注意：本项目不提供预编译安装包，README 中明确说明需要自行编译后运行测试。

## 技术栈

- **语言**：Dart
- **框架**：Flutter 3.38.x（仓库中 `.fvmrc` 锁定 `3.38.3`）
- **状态管理**：GetX
- **网络请求**：Dio
- **本地持久化**：Hive
- **日志**：logger 包
- **视频播放**：media_kit
- **弹幕**：canvas_danmaku
- **WebSocket**：web_socket_channel
- **JSON / 序列化**：手写模型 + `json.encode` / `json.decode`
- **二进制协议**：Tars（虎牙相关接口），由 `simple_live_core/packages/tars_dart` 本地包提供
- **签名脚本**：抖音/斗鱼相关签名由 Dart 实现的 JS 签名脚本处理（`src/scripts/douyin_sign.dart`、`src/scripts/douyu_sign.dart`）

## 代码组织

### simple_live_core（核心库）

核心库不依赖 Flutter，仅依赖 Dart 包，因此命令行与 Flutter 两端都可复用。

```
simple_live_core/lib/
├── simple_live_core.dart          # 对外统一导出
└── src/
    ├── interface/
    │   ├── live_site.dart         # LiveSite 抽象接口
    │   └── live_danmaku.dart      # LiveDanmaku 抽象接口
    ├── huya_site.dart             # 虎牙直播实现
    ├── bilibili_site.dart         # 哔哩哔哩直播实现
    ├── douyu_site.dart            # 斗鱼直播实现
    ├── douyin_site.dart           # 抖音直播实现
    ├── common/
    │   ├── http_client.dart       # 基于 Dio 的通用 HTTP 客户端
    │   ├── web_socket_util.dart   # WebSocket 封装（含心跳、重连）
    │   ├── core_log.dart          # 日志工具
    │   ├── core_error.dart        # 错误类
    │   ├── custom_interceptor.dart
    │   ├── convert_helper.dart
    │   └── binary_writer.dart
    ├── model/                     # 数据模型
    │   ├── live_room_item.dart
    │   ├── live_room_detail.dart
    │   ├── live_category.dart
    │   ├── live_category_result.dart
    │   ├── live_play_quality.dart
    │   ├── live_play_url.dart
    │   ├── live_search_result.dart
    │   ├── live_anchor_item.dart
    │   ├── live_message.dart
    │   └── tars/                  # 虎牙 Tars 协议相关模型
    └── danmaku/                   # 各平台弹幕实现
        ├── bilibili_danmaku.dart
        ├── douyu_danmaku.dart
        ├── huya_danmaku.dart
        ├── douyin_danmaku.dart
        └── proto/                 # 抖音 Protobuf 定义与生成代码
```

核心接口：

- `LiveSite`：所有直播平台必须实现该接口，提供分类、搜索、房间详情、清晰度、播放链接、弹幕实例等能力。
- `LiveDanmaku`：弹幕连接抽象，通过回调 `onMessage`、`onClose`、`onReady` 传递弹幕事件。

### simple_live_app（移动/桌面客户端）

```
simple_live_app/lib/
├── main.dart
├── app/
│   ├── app_style.dart
│   ├── controller/
│   │   ├── base_controller.dart        # 含分页控制器基类
│   │   └── app_settings_controller.dart
│   └── utils/
├── models/
│   ├── db/                             # Hive 数据模型
│   │   ├── follow_user.dart
│   │   ├── follow_user_tag.dart
│   │   └── history.dart
│   └── account/
├── modules/
│   ├── indexed/                        # 首页底部导航
│   ├── home/                           # 推荐
│   ├── category/                       # 分类
│   ├── live_room/                      # 直播间（含播放器）
│   ├── search/
│   ├── follow_user/
│   ├── mine/                           # 我的/账号/历史/解析
│   ├── settings/                       # 设置
│   ├── sync/                           # 数据同步（局域网/WebDAV）
│   └── other/
├── requests/                           # 业务请求封装
├── routes/
│   ├── route_path.dart                 # 路由常量
│   └── app_pages.dart                  # GetX 路由配置
├── services/                           # GetX 服务
│   ├── db_service.dart
│   ├── follow_service.dart
│   ├── local_storage_service.dart
│   ├── sync_service.dart
│   ├── signalr_service.dart
│   ├── bilibili_account_service.dart
│   └── douyin_account_service.dart
└── widgets/                            # 公共组件
```

### simple_live_tv_app（Android TV 客户端）

结构与 `simple_live_app` 类似，同样使用 GetX + Hive + media_kit，但 UI 针对 TV 遥控器与大屏设计，强制横屏并隐藏系统 UI。

```
simple_live_tv_app/lib/
├── main.dart
├── app/
├── models/
├── modules/
├── requests/
├── routes/
├── services/
└── widgets/
```

### simple_live_console（命令行工具）

```
simple_live_console/bin/simple_live_console.dart
```

支持参数：

- `-i [URL]`：获取直播间信息及播放直链
- `-d [URL]`：持续输出直播间弹幕
- `-s [keyword]`：抖音搜索直播间
- `-r [webRid]`：抖音通过 webRid 获取房间详情
- `-h`：帮助

## 构建与运行

### 环境要求

- Flutter SDK `3.38.x`（推荐使用 FVM 并按 `.fvmrc` 锁定 `3.38.3`）
- Dart SDK `>=3.10.0`（核心库/控制台）
- Android 构建：JDK 17、Gradle 8.12、Android SDK
- iOS/macOS 构建：Xcode
- Windows 构建：Visual Studio / CMake
- Linux 构建：clang、cmake、ninja、libgtk-3-dev、libmpv-dev 等

### 常用命令

```bash
# 安装核心库依赖
cd simple_live_core && dart pub get

# 运行核心库测试（会真实访问各平台接口，可能因网络/反爬失败）
cd simple_live_core && dart test

# 运行控制台工具
cd simple_live_console && dart run bin/simple_live_console.dart -i "https://live.bilibili.com/xxx"

# 安装 APP 依赖
cd simple_live_app && flutter pub get

# 运行 APP（Android 示例）
cd simple_live_app && flutter run

# 构建 Android APK
cd simple_live_app && flutter build apk --release --split-per-abi

# 静态分析
cd simple_live_app && flutter analyze
cd simple_live_tv_app && flutter analyze
cd simple_live_core && dart analyze
```

### 平台构建说明

- Android 签名通过 `android/key.properties` 配置，该文件不被提交到仓库。
- 桌面平台构建使用 `flutter_distributor`，配置在 `simple_live_app/distribute_options.yaml` 中（`output: build/dist/`）。
- TV 应用只构建 Android APK，包名为 `com.xycz.simple_live_tv`。

## 测试策略

- **核心库测试**：`simple_live_core/test/simple_live_core_test.dart` 包含对四个直播平台（BiliBili、Douyu、Huya、Douyin）的集成测试，测试项覆盖：
  - 推荐房间
  - 分类列表
  - 分类下房间
  - 搜索房间/主播
  - 房间详情
  - 清晰度列表
  - 播放直链
  - 弹幕连接（连接 30 秒并验证收到消息）
  
  这些测试依赖真实网络环境，可能因平台接口变动、反爬策略或网络问题失败。

- **APP 测试**：`simple_live_app/test/widget_test.dart` 和 `simple_live_tv_app/test/widget_test.dart` 是 Flutter 默认生成的占位 Widget 测试，目前未覆盖实际业务逻辑。

- **控制台测试**：`simple_live_console/test/all_live_console_test.dart` 是占位测试。

## 代码风格与开发约定

- 使用 `analysis_options.yaml` 配置静态分析：
  - `simple_live_core`、`simple_live_console`：使用 `package:lints/recommended.yaml`
  - `simple_live_app`、`simple_live_tv_app`：使用 `package:flutter_lints/flutter.yaml`
- 命名与结构遵循 Dart 社区约定。
- 模型类通常手写 `toString()` 并返回 `json.encode(...)`，便于日志输出。
- 注释多为中文，代码中的字符串与提示信息也多为中文。
- 业务逻辑放在 `services/` 或 `controllers/` 中，页面放在 `modules/`，路由集中在 `routes/`。
- 数据持久化使用 Hive，模型需配合 `.g.dart` 生成文件；APP 端使用 `build_runner` + `hive_generator`。

## 持续集成 / 发布

仓库使用 GitHub Actions 自动构建，工作流位于 `.github/workflows/`：

- `publish_app_release.yml`：推送 `v*` 标签时触发，构建 Android、iOS、macOS、Linux、Windows 安装包并发布到 GitHub Release。
- `publish_app_dev.yaml`：推送 `dev_v*` 标签时触发，构建但不发布 Release，仅上传 Artifacts。
- `publish_tv_app_release.yaml`：推送 `tv_*` 标签时触发，构建 TV 版 Android APK 并发布 Release。
- `publish_tv_app_dev.yaml`：推送 `dev_tv_v*` 标签时触发，构建 TV 版 APK 并上传 Artifacts。

CI 中使用到的 Secrets：

- `KEYSTORE_BASE64`、`STORE_PASSWORD`、`KEY_PASSWORD`、`KEY_ALIAS`：APP 签名
- `TV_KEYSTORE_BASE64`、`TV_STORE_PASSWORD`、`TV_KEY_PASSWORD`、`TV_KEY_ALIAS`：TV 应用签名
- `TOKEN`：发布 Release 用 GitHub Token

## 安全与合规提示

- 本项目声明所有功能基于互联网公开资料开发，无破解、逆向工程行为，仅用于学习交流编程技术。
- 请勿将本项目用于商业目的。
- 代码中直接硬编码了部分 User-Agent、Cookie、签名脚本与请求头。修改时请注意不要提交真实账号凭证或敏感密钥。
- 抖音接口依赖 `ttwid` Cookie 与签名脚本，相关逻辑在 `douyin_site.dart` 与 `douyin_sign.dart` 中；反爬策略可能频繁变化，需要持续维护。
- 虎牙接口使用 Tars 二进制协议，依赖本地包 `tars_dart`。

## 给代理的常用入口

- 新增直播平台：实现 `simple_live_core/lib/src/interface/live_site.dart` 与 `simple_live_core/lib/src/interface/live_danmaku.dart`，然后在 `simple_live_core/lib/simple_live_core.dart` 导出。
- 修改平台数据解析：直接编辑对应的 `*_site.dart` 文件。
- 修改弹幕协议：编辑 `simple_live_core/lib/src/danmaku/*_danmaku.dart`。
- 新增 APP 页面：在 `simple_live_app/lib/modules/` 添加 `controller` + `page`，在 `routes/` 注册路由。
- 新增本地存储模型：在 `models/db/` 定义 Hive 模型并生成适配器，在 `services/db_service.dart` 中管理 Box。
- 调整构建/打包：修改 `pubspec.yaml`、`android/app/build.gradle.kts`、CI workflow 或 `distribute_options.yaml`。
