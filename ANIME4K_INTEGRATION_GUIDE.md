# Anime4K 超分辨率模块集成指南

本文档说明如何在 Venera 项目中使用集成的 Anime4K 超分辨率模块。

## 概述

Anime4K 是一个高效的动漫/漫画图像超分辨率处理算法，已成功从 JhentaiSR 项目移植到 Venera。该模块提供以下功能：

- **智能超分处理**：基于 Anime4K v1.0 的 "Push Pixels" 算法
- **缓存机制**：避免重复处理相同图像
- **并发控制**：最多 2 个并发任务，防止过度占用资源
- **灵活配置**：支持放大倍数、线条细化强度等参数调整

## 文件结构

```
lib/
├── utils/
│   └── anime4k/
│       ├── anime4k_service.dart      # 超分服务（单例模式）
│       └── anime4k_upscaler.dart     # 超分算法实现
├── pages/
│   └── reader/
│       └── comic_image.dart          # 集成 Anime4K 的图像组件（已修改）
└── foundation/
    └── appdata.dart                  # 配置管理（已支持 Anime4K 参数）
```

## 核心改动

### 1. 日志调用修复

**问题**：JhentaiSR 使用 `log.debug()` 和 `log.error()` 方式调用日志

**解决方案**：Venera 使用 `Log.info()` 和 `Log.error()` 方式，已在以下文件中修复：

- `lib/utils/anime4k/anime4k_service.dart`：所有日志调用已改为 `Log.info()` 和 `Log.error()`

### 2. eh_image.dart 变量定义问题

**问题**：JhentaiSR 的 `eh_image.dart` 中 `fit`、`containerWidth`、`containerHeight` 在 `_EHImageState` 中未定义

**解决方案**：

- Venera 的 `comic_image.dart` 中已正确定义了所有必需的变量：
  - `_upscaledBytes`：存储超分后的图像字节数据
  - `_isUpscaling`：标记是否正在处理中
  - 所有 widget 参数通过 `widget.` 前缀访问

### 3. 签名配置问题

**原始问题**：`android/app/build.gradle` 中的 release 签名配置需要 `key.properties` 文件

**解决方案**：提供了两种方案

#### 方案 A：使用 Debug 签名（推荐用于开发）

使用提供的 `build.gradle.debug` 文件，该文件配置为使用 Android 默认的 debug keystore：

```bash
# 替换原配置文件
cp android/app/build.gradle android/app/build.gradle.release
cp android/app/build.gradle.debug android/app/build.gradle

# 构建 debug 版本
flutter build apk --debug
```

#### 方案 B：创建 Release 签名配置（推荐用于发布）

创建 `android/key.properties` 文件：

```properties
storeFile=/path/to/your/keystore.jks
storePassword=your_store_password
keyAlias=your_key_alias
keyPassword=your_key_password
```

然后构建：

```bash
flutter build apk --release
```

## 配置项说明

在 `lib/foundation/appdata.dart` 中已添加以下 Anime4K 配置项：

| 配置项 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `enableAnime4K` | bool | false | 是否启用 Anime4K 超分 |
| `anime4KScaleFactor` | double | 2.0 | 放大倍数（1.0-4.0） |
| `anime4KPushStrength` | double | 0.31 | 线条细化强度（0.0-1.0） |
| `anime4KPushGradStrength` | double | 1.0 | 梯度精炼强度（0.0-1.0） |

## 使用方法

### 1. 初始化服务

在应用启动时初始化 Anime4K 服务（在 `lib/init.dart` 中添加）：

```dart
import 'package:venera/utils/anime4k/anime4k_service.dart';

Future<void> init() async {
  // ... 其他初始化代码 ...
  
  // 初始化 Anime4K 服务
  await Anime4KService.instance.init();
  
  // ... 其他初始化代码 ...
}
```

### 2. 在设置界面中添加控制

在 `lib/pages/settings/reader.dart` 中添加 Anime4K 设置选项：

```dart
// 启用/禁用 Anime4K
SwitchListTile(
  title: const Text('Enable Anime4K Upscaling'),
  value: appdata.settings['enableAnime4K'] ?? false,
  onChanged: (value) {
    appdata.settings['enableAnime4K'] = value;
    appdata.saveData();
  },
),

// 放大倍数
Slider(
  value: (appdata.settings['anime4KScaleFactor'] as num?)?.toDouble() ?? 2.0,
  min: 1.0,
  max: 4.0,
  divisions: 3,
  label: 'Scale Factor',
  onChanged: (value) {
    appdata.settings['anime4KScaleFactor'] = value;
    appdata.saveData();
  },
),

// 线条细化强度
Slider(
  value: (appdata.settings['anime4KPushStrength'] as num?)?.toDouble() ?? 0.31,
  min: 0.0,
  max: 1.0,
  divisions: 10,
  label: 'Push Strength',
  onChanged: (value) {
    appdata.settings['anime4KPushStrength'] = value;
    appdata.saveData();
  },
),

// 梯度精炼强度
Slider(
  value: (appdata.settings['anime4KPushGradStrength'] as num?)?.toDouble() ?? 1.0,
  min: 0.0,
  max: 1.0,
  divisions: 10,
  label: 'Gradient Refine Strength',
  onChanged: (value) {
    appdata.settings['anime4KPushGradStrength'] = value;
    appdata.saveData();
  },
),
```

### 3. 清除缓存

在设置中提供清除 Anime4K 缓存的选项：

```dart
ElevatedButton(
  onPressed: () async {
    await Anime4KService.instance.clearCache();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Anime4K cache cleared')),
    );
  },
  child: const Text('Clear Anime4K Cache'),
),
```

## 性能考虑

1. **缓存目录**：超分后的图像存储在 `getTemporaryDirectory()/anime4k_cache/`
2. **并发限制**：最多同时处理 2 张图片，防止内存溢出
3. **任务队列**：超过并发限制的任务会排队处理
4. **缓存策略**：相同参数的图像只处理一次，后续直接使用缓存

## 依赖项

确保 `pubspec.yaml` 中包含以下依赖：

```yaml
dependencies:
  image: any  # 用于图像编解码
  path_provider: any  # 用于获取临时目录
  path: any  # 用于路径操作
```

## 故障排查

### 问题 1：Anime4K 处理失败

**症状**：日志中出现 "Anime4K processing error"

**解决方案**：
- 检查图像格式是否支持（PNG、JPG、GIF 等）
- 检查可用内存是否充足
- 检查临时目录是否可写

### 问题 2：签名错误

**症状**：构建时出现 "Keystore was tampered with, or password was incorrect"

**解决方案**：
- 使用 debug 版本（`build.gradle.debug`）
- 或者正确配置 `key.properties` 文件
- 确保 keystore 文件路径正确

### 问题 3：内存溢出

**症状**：处理大图片时应用崩溃

**解决方案**：
- 减少 `anime4KScaleFactor`（使用 2.0 而不是 4.0）
- 减少 `anime4KPushStrength` 和 `anime4KPushGradStrength`
- 清除 Anime4K 缓存以释放空间

## 测试

### 单元测试示例

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:venera/utils/anime4k/anime4k_service.dart';

void main() {
  test('Anime4K service initialization', () async {
    final service = Anime4KService.instance;
    await service.init();
    expect(service, isNotNull);
  });

  test('Anime4K image processing', () async {
    final service = Anime4KService.instance;
    // ... 测试代码 ...
  });
}
```

## 参考资源

- **Anime4K 官方**：https://github.com/bloc97/Anime4K
- **JhentaiSR 项目**：https://github.com/jhenil/JhentaiSR
- **Venera 项目**：https://github.com/venera-app/venera

## 许可证

本模块遵循原始项目的许可证。请参考相应项目的 LICENSE 文件。
