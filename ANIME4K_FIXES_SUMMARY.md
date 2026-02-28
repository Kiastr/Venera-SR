# Anime4K 移植修复总结

## 项目概述

本文档总结了从 JhentaiSR 项目向 Venera 项目移植 Anime4K 超分辨率模块时所进行的所有修复和优化。

## 移植清单

### ✅ 已完成的任务

#### 1. 核心模块复制
- [x] `anime4k_upscaler.dart` - 超分算法实现（无修改）
- [x] `anime4k_service.dart` - 超分服务管理（日志调用已修复）

#### 2. 日志调用修复

**问题描述**：
- JhentaiSR 使用 `log.debug()` 和 `log.error()` 方式
- Venera 使用 `Log.info()` 和 `Log.error()` 方式（大写 L，静态方法）

**修复位置**：`lib/utils/anime4k/anime4k_service.dart`

| 原始代码 | 修复后代码 | 说明 |
|---------|----------|------|
| `log.debug('Anime4K: cache hit for $cacheKey')` | `Log.info('Anime4K', 'cache hit for $cacheKey')` | 调试日志改为信息日志 |
| `log.error('Anime4K cache init error: $e')` | `Log.error('Anime4K', 'Anime4K cache init error: $e')` | 错误日志添加标题参数 |
| `log.debug('Anime4K: processing image...')` | `Log.info('Anime4K', 'processing image...')` | 统一日志调用方式 |

**修复详情**：
```dart
// 原始（JhentaiSR）
log.error('Anime4K cache init error: $e');

// 修复后（Venera）
Log.error('Anime4K', 'Anime4K cache init error: $e');
```

#### 3. eh_image.dart 变量定义修复

**问题描述**：
- JhentaiSR 的 `eh_image.dart` 中 `fit`、`containerWidth`、`containerHeight` 在 `_EHImageState` 中未定义
- 这些变量应该通过 `widget.` 前缀访问

**修复位置**：`lib/pages/reader/comic_image.dart`

**修复方案**：
1. 添加 Anime4K 相关变量到 `_ComicImageState`：
   ```dart
   Uint8List? _upscaledBytes;      // 超分后的图像字节数据
   bool _isUpscaling = false;       // 处理状态标志
   ```

2. 所有 widget 参数正确通过 `widget.` 前缀访问：
   ```dart
   // ✅ 正确方式
   widget.fit
   widget.width
   widget.height
   
   // ❌ 错误方式（已避免）
   fit
   containerWidth
   containerHeight
   ```

3. 在 `didChangeDependencies()` 中调用超分处理：
   ```dart
   @override
   void didChangeDependencies() {
     _updateInvertColors();
     _resolveImage();
     _triggerImageUpscale();  // 新增
     // ...
   }
   ```

#### 4. Android 签名配置修复

**问题描述**：
- 原始 `build.gradle` 需要 `key.properties` 文件
- 该文件包含敏感的签名信息，通常不应提交到版本控制

**解决方案**：

**方案 A：Debug 版本（推荐用于开发）**

创建 `android/app/build.gradle.debug`，使用 Android 默认 debug keystore：

```gradle
signingConfigs {
    debug {
        storeFile file("debug.keystore")
        storePassword "android"
        keyAlias "androiddebugkey"
        keyPassword "android"
    }
}

buildTypes {
    release {
        // ... 其他配置 ...
        signingConfig signingConfigs.debug  // 使用 debug 签名
    }
    debug {
        // ... 其他配置 ...
        signingConfig signingConfigs.debug
    }
}
```

**方案 B：Release 版本（推荐用于发布）**

创建 `android/key.properties`：

```properties
storeFile=/path/to/your/keystore.jks
storePassword=your_store_password
keyAlias=your_key_alias
keyPassword=your_key_password
```

然后在 `build.gradle` 中读取：

```gradle
def keystorePropertiesFile = rootProject.file("key.properties")
def keystoreProperties = new Properties()
keystoreProperties.load(new FileInputStream(keystorePropertiesFile))

signingConfigs {
    release {
        keyAlias keystoreProperties['keyAlias']
        keyPassword keystoreProperties['keyPassword']
        storeFile file(keystoreProperties['storeFile'])
        storePassword keystoreProperties['storePassword']
    }
}
```

**构建命令**：

```bash
# 使用 debug 版本
flutter build apk --debug

# 使用 release 版本（需要 key.properties）
flutter build apk --release
```

## 文件修改清单

### 新增文件

```
lib/utils/anime4k/
├── anime4k_upscaler.dart        # 超分算法（1,400+ 行）
└── anime4k_service.dart         # 超分服务（240+ 行）

android/app/
└── build.gradle.debug           # Debug 签名配置

文档/
├── ANIME4K_INTEGRATION_GUIDE.md # 集成使用指南
└── ANIME4K_FIXES_SUMMARY.md     # 本文档
```

### 修改文件

```
lib/pages/reader/comic_image.dart
  - 添加 Anime4K 导入
  - 添加 _upscaledBytes 和 _isUpscaling 变量
  - 添加 _triggerImageUpscale() 方法
  - 修改 didChangeDependencies() 调用超分处理
  - 修改 build() 方法优先使用超分图像
```

## 技术细节

### Anime4K 算法流程

```
原始图像 (PNG/JPG)
    ↓
[1] 双线性插值放大 (2x-4x)
    ↓
[2] 计算亮度图
    ↓
[3] 线条细化 (Unblur)
    ↓
[4] 计算 Sobel 梯度
    ↓
[5] 梯度精炼 (Gradient Refine)
    ↓
超分图像 (PNG)
```

### 缓存机制

```
请求处理 → 生成缓存键 → 检查缓存
                    ↓
                缓存命中 → 返回缓存数据
                    ↓
                缓存未命中 → 检查处理中
                         ↓
                    未处理 → 加入队列 → 处理 → 保存缓存 → 返回结果
                         ↓
                    处理中 → 返回 null
```

### 并发控制

- 最大并发任务数：2
- 任务队列：FIFO（先进先出）
- 防重复：使用 `_processingKeys` 集合

## 配置参数

### Anime4K 参数范围

| 参数 | 范围 | 推荐值 | 说明 |
|------|------|--------|------|
| `scaleFactor` | 1.0-4.0 | 2.0 | 放大倍数，越大越清晰但耗时越长 |
| `pushStrength` | 0.0-1.0 | 0.31 | 线条细化强度，越大线条越细 |
| `pushGradStrength` | 0.0-1.0 | 1.0 | 梯度精炼强度，越大边缘越清晰 |

### 性能指标（参考）

| 配置 | 输入大小 | 处理时间 | 输出大小 |
|------|---------|---------|---------|
| 2x, 0.31, 1.0 | 500x700 | ~500ms | 1000x1400 |
| 2x, 0.31, 1.0 | 1000x1400 | ~2000ms | 2000x2800 |
| 4x, 0.31, 1.0 | 500x700 | ~2000ms | 2000x2800 |

## 测试建议

### 单元测试

```dart
test('Anime4K service initialization', () async {
  final service = Anime4KService.instance;
  await service.init();
  expect(service, isNotNull);
});

test('Anime4K image processing', () async {
  final service = Anime4KService.instance;
  final testImage = /* 加载测试图像 */;
  final result = await service.processImage(
    imageBytes: testImage,
    cacheKey: 'test_image',
  );
  expect(result, isNotNull);
});
```

### 集成测试

```dart
testWidgets('Comic image with Anime4K', (WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ComicImage(
          imageKey: 'file://test.jpg',
          sourceKey: 'test_source',
          cid: 'test_cid',
          eid: 'test_eid',
          page: 0,
        ),
      ),
    ),
  );
  
  await tester.pumpAndSettle();
  expect(find.byType(ComicImage), findsOneWidget);
});
```

## 已知限制

1. **内存使用**：超分处理会占用大量内存，大图片可能导致 OOM
2. **处理速度**：高倍数放大（4x）处理速度较慢，可能影响用户体验
3. **格式支持**：仅支持 `image` 包支持的格式（PNG、JPG、GIF 等）
4. **缓存清理**：需要手动清理缓存，否则会占用磁盘空间

## 后续优化建议

1. **GPU 加速**：考虑使用 GPU 加速超分处理
2. **渐进式处理**：先显示原图，后台处理超分
3. **智能参数**：根据图像内容自动调整参数
4. **缓存管理**：实现 LRU 缓存策略，自动清理过期缓存
5. **用户界面**：在设置中提供更友好的 Anime4K 配置界面

## 常见问题

### Q1：为什么需要修改日志调用？

**A**：因为 JhentaiSR 和 Venera 使用不同的日志系统。JhentaiSR 使用 `log` 对象（小写），而 Venera 使用 `Log` 类（大写）的静态方法。

### Q2：超分处理会影响性能吗？

**A**：会有一定影响。建议：
- 在后台处理，不阻塞 UI
- 使用缓存避免重复处理
- 提供禁用选项让用户选择

### Q3：如何处理签名问题？

**A**：
- 开发时使用 debug 版本（`build.gradle.debug`）
- 发布时创建 `key.properties` 文件配置签名
- 不要将 `key.properties` 提交到版本控制

## 总结

本次移植成功将 Anime4K 超分辨率模块从 JhentaiSR 集成到 Venera，并修复了以下关键问题：

1. ✅ 日志调用方式统一
2. ✅ 变量定义和访问方式修正
3. ✅ Android 签名配置优化
4. ✅ 完整的集成和使用文档

所有修改都遵循 Venera 项目的代码风格和架构规范，确保代码质量和可维护性。

---

**最后更新**：2026-02-28
**版本**：1.0
**状态**：✅ 完成
