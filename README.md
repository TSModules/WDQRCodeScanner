# WDQRCodeScanner

WDQRCodeScanner 是一个功能强大的 iOS 二维码扫描组件，基于 AVFoundation 框架开发，提供了简单易用的 API 接口。

## 功能特点

- 🎯 实时二维码扫描
- 💡 闪光灯控制
- 📸 相机权限管理
- 🔄 状态管理与回调
- 🎨 自定义扫描界面
- 📱 支持 SwiftUI 和 UIKit

## 系统要求

- iOS 13.0+
- Swift 5.0+
- Xcode 13.0+

## 安装方法

### Swift Package Manager

WDQRCodeScanner 支持 Swift Package Manager 安装。

1. 在 Xcode 中，选择 File → Add Packages...
2. 输入仓库地址：
```ruby
https://github.com/TSModules/WDQRCodeScanner.git
```
3. 选择版本规则（建议选择 "Up to Next Major Version"）
4. 点击 "Add Package" 完成安装

也可以将依赖项添加到 `Package.swift` 文件中：

```swift
.package(url: "https://github.com/TSModules/WDQRCodeScanner.git", from: "1.0.0")
```

然后在需要使用的 target 中添加依赖：
```swift
targets: [
    .target(
        name: "YourTarget",
        dependencies: ["WDQRCodeScanner"]
    )
]
```

### 导入

在需要使用的文件中导入模块：

```swift
import WDQRCodeScanner
```

## 核心组件

### WDQRScannerService

扫描服务的核心类，负责：
- 相机设备管理
- 二维码扫描
- 闪光灯控制
- 扫描状态管理

### WDQRScannerViewModel

视图模型层，处理：
- 业务逻辑
- 状态转换
- 用户交互响应

### WDQRScannerViewController

界面展示层，提供：
- 扫描预览界面
- 用户交互界面
- 扫描结果展示

## 使用方法

### 1. 简单使用
```swift
let viewController = WDQRScannerViewController()
self.navigationController?.pushViewController(viewController, animated: true)
```
### 2. 自定义
直接使用核心扫描服务，完全自定义扫描界面，
```swift
let service = WDQRScannerService()
```

## 注意事项

1. 使用前需要在 Info.plist 中添加相机权限描述：
```xml
<key>NSCameraUsageDescription</key>
<string>需要使用相机进行二维码扫描</string>
```
2. 建议在不需要扫描时调用 stopScanning() 以节省电量

## 错误处理

扫描器定义了以下错误类型：
- `invalidDeviceInput`: 设备输入无效
- `captureSessionSetupFailed`: 会话设置失败
- `cameraAccessDenied`: 相机访问被拒绝
- `cameraAccessRestricted`: 相机访问受限
- `unknownError`: 未知错误

## 许可证
[MIT License](LICENSE)

