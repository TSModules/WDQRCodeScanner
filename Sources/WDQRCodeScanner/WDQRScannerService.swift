import AVFoundation
import Combine
import Dispatch
import UIKit

public struct WDQRScannerResult: @unchecked Sendable {
    let value: String?
    let corners: [CGPoint]
    let metaObject: AVMetadataMachineReadableCodeObject
}

/// 扫描器的状态枚举
public enum WDQRScannerState: @unchecked Sendable {
    case idle           // 空闲状态
    case scanning      // 正在扫描
    case found([WDQRScannerResult]) // 找到二维码
    case error(Error)  // 发生错误
}

/// 扫描器错误类型
public enum WDQRScannerError: Error, @unchecked Sendable {
    case invalidDeviceInput
    case captureSessionSetupFailed
    case cameraAccessDenied
    case cameraAccessRestricted
    case unknownError
}

/// 二维码扫描服务类
final public class WDQRScannerService: NSObject, @unchecked Sendable {

    // MARK: - Published 属性
    @Published public private(set) var state: WDQRScannerState = .idle
    @Published public private(set) var isTorchActive = false
    @Published public private(set) var sampleBuffer: CMSampleBuffer?
    
    public let captureSession = AVCaptureSession()
    
    // MARK: - 初始化方法
    public override init() {
        super.init()
        setupCaptureSession()
    }
    
    // MARK: - Public 方法
    
    /// 开始扫描
    public func startScanning() {
        guard !captureSession.isRunning else { return }
        guard metadataOutputEnable else { return }
        
        metadataQueue.async { [weak self] in
            guard let self else { return }
            self.captureSession.startRunning()
            DispatchQueue.main.async {
                self.videoDataOutputEnable = false
                self.state = .scanning
            }
        }
    }
    
    /// 停止扫描
    public func stopScanning() {
        guard captureSession.isRunning else { return }
        guard metadataOutputEnable else { return }
        
        metadataQueue.async { [weak self] in
            guard let self else { return }
            self.captureSession.stopRunning()
            DispatchQueue.main.async {
                self.videoDataOutputEnable = false
                self.state = .idle
            }
        }
    }
    
    /// 切换闪光灯
    public func toggleTorch() {
        guard let device = captureDevice, device.hasTorch else { return }
        
        do {
            try device.lockForConfiguration()
            device.torchMode = device.torchMode == .on ? .off : .on
            isTorchActive = device.torchMode == .on
            device.unlockForConfiguration()
        } catch {
            state = .error(WDQRScannerError.unknownError)
        }
    }
    
    // MARK: - Private 属性
    private let metadataOutput = AVCaptureMetadataOutput()
    private var metadataOutputEnable = false
    private var videoDataOutput = AVCaptureVideoDataOutput()
    private var videoDataOutputEnable = false
    private var captureDevice: AVCaptureDevice?
    private var cancellables = Set<AnyCancellable>()
    private let metadataQueue = DispatchQueue(label: "com.metadata.session.qrreader.queue")
    private let videoDataQueue = DispatchQueue(label: "com.videoData.session.qrreader.queue")
}

// MARK: - Private Setup Methods
private extension WDQRScannerService {
    
    func setupCaptureSession() {
        // 检查相机权限
        Task {
            let granted = await checkCameraPermission()
            if granted {
                self.configureCaptureSession()
            }
        }
    }
    
    func checkCameraPermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        case .denied:
            state = .error(WDQRScannerError.cameraAccessDenied)
            return false
        case .restricted:
            state = .error(WDQRScannerError.cameraAccessRestricted)
            return false
        @unknown default:
            state = .error(WDQRScannerError.unknownError)
            return false
        }
    }
    
    func isAuthorized() -> Bool {
        AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    }
    
    func configureCaptureSession() {
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            state = .error(WDQRScannerError.invalidDeviceInput)
            return
        }
        captureDevice = videoCaptureDevice
        
        do {
            captureSession.beginConfiguration()

            let videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
            if captureSession.canAddInput(videoInput) {
                captureSession.addInput(videoInput)
            }
            
            if captureSession.canAddOutput(metadataOutput) {
                captureSession.addOutput(metadataOutput)
                metadataOutput.setMetadataObjectsDelegate(self, queue: metadataQueue)
                metadataOutput.metadataObjectTypes = [.qr]
            }
            
            if captureSession.canAddOutput(videoDataOutput) {
                videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
                videoDataOutput.setSampleBufferDelegate(self, queue: videoDataQueue)
                captureSession.addOutput(videoDataOutput)
            }
            
            captureSession.commitConfiguration()
            
            metadataOutputEnable = true
            startScanning()
            
        } catch {
            state = .error(WDQRScannerError.captureSessionSetupFailed)
        }
    }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate
extension WDQRScannerService: AVCaptureMetadataOutputObjectsDelegate {
    
    public func metadataOutput(_ output: AVCaptureMetadataOutput,
                       didOutput metadataObjects: [AVMetadataObject], 
                       from connection: AVCaptureConnection) {
        
        let outputs = metadataObjects.compactMap({ $0 as? AVMetadataMachineReadableCodeObject }).filter({ $0.type == .qr }).map({ WDQRScannerResult(value: $0.stringValue, corners: $0.corners, metaObject: $0) })
        state = .found(outputs)
        videoDataOutputEnable = true
        stopScanning()
    }
} 

extension WDQRScannerService: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    public func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
    }
    
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard videoDataOutputEnable else { return }
        self.sampleBuffer = sampleBuffer
        videoDataOutputEnable = false
    }
}

