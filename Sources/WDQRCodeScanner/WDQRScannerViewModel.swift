import Foundation
import Combine
import AVFoundation

final public class WDQRScannerViewModel {
    // MARK: - public 属性
    @Published public var scannerMessage: String = "将二维码放入框内"
    @Published public var showAlert: Bool = false
    @Published public var alertMessage: String = ""
    @Published public var isScanningEnabled: Bool = false
    @Published public var isTorchEnabled: Bool = false
    
    @Published public var scanResults: [WDQRScannerResult]?
    
    public let scannerService: WDQRScannerService
    
    // MARK: - Private 属性
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - 初始化方法
    public init(scannerService: WDQRScannerService = WDQRScannerService()) {
        self.scannerService = scannerService
        setupBindings()
    }
    
    // MARK: - Public 方法
    public func startScanning() {
        scannerService.startScanning()
    }
    
    public func stopScanning() {
        scannerService.stopScanning()
    }
    
    public func toggleTorch() {
        scannerService.toggleTorch()
    }
    
    // MARK: - Private 方法
    private func setupBindings() {
        // 监听扫描器状态变化
        scannerService.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.handleScannerState(state)
            }
            .store(in: &cancellables)
        
        // 监听闪光灯状态
        scannerService.$isTorchActive
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: { [weak self] isTorchActive in
                guard let self else { return }
                self.isTorchEnabled = isTorchActive
            })
            .store(in: &cancellables)
    }
    
    private func handleScannerState(_ state: WDQRScannerState) {
        switch state {
        case .idle:
            scannerMessage = "将二维码放入框内"
            isScanningEnabled = false
            
        case .scanning:
            scannerMessage = "正在扫描..."
            isScanningEnabled = true
            
        case .found(let results):
            scannerMessage = "扫描成功"
            isScanningEnabled = false
            scanResults = results
            
        case .error(let error):
            handleError(error)
        }
    }
    
    private func handleScannedCode(_ results: [WDQRScannerResult]) {
        if results.count > 1 {
            
        } else {
            
        }
        showAlert = true
        alertMessage = "扫描到的内容：\(results.compactMap(\.value).joined(separator: "\n"))"
    }
    
    private func handleError(_ error: Error) {
        isScanningEnabled = false
        showAlert = true
        
        if let scannerError = error as? WDQRScannerError {
            alertMessage = getErrorMessage(for: scannerError)
        } else {
            alertMessage = "发生未知错误"
        }
    }
    
    private func getErrorMessage(for error: WDQRScannerError) -> String {
        switch error {
        case .cameraAccessDenied:
            return "没有相机访问权限，请在设置中允许访问相机"
        case .cameraAccessRestricted:
            return "相机访问受限"
        case .invalidDeviceInput:
            return "无法访问相机设备"
        case .captureSessionSetupFailed:
            return "相机设置失败"
        case .unknownError:
            return "发生未知错误"
        }
    }
}

// MARK: - Preview Helper
extension WDQRScannerViewModel {
    
    static var preview: WDQRScannerViewModel {
        let viewModel = WDQRScannerViewModel()
        // 设置预览数据
        return viewModel
    }
} 
