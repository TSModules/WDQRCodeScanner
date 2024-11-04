import UIKit
import AVFoundation
import Combine

open class WDQRScannerViewController: UIViewController {
    
    @Published private(set) var currentScanResult: String?
    
    private var cancellables = Set<AnyCancellable>()
    private var resultBtnCancellables = Set<AnyCancellable>()
    
    // MARK: - Properties
    public let viewModel: WDQRScannerViewModel
    
    // MARK: - UI Components
    public lazy var previewLayer: AVCaptureVideoPreviewLayer = {
        let layer = AVCaptureVideoPreviewLayer(session: viewModel.scannerService.captureSession)
        layer.videoGravity = .resizeAspectFill
        return layer
    }()
    
    private lazy var scannerOverlay: QRScannerOverlayView = {
        let overlay = QRScannerOverlayView()
        overlay.translatesAutoresizingMaskIntoConstraints = false
        return overlay
    }()
    
    private lazy var messageLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.textColor = .white
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        label.layer.cornerRadius = 8
        label.clipsToBounds = true
        label.numberOfLines = 0
        label.padding = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        return label
    }()
    
    private lazy var controlStackView: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.spacing = 60
        stack.distribution = .fillEqually
        return stack
    }()
    
    private lazy var torchButton: UIButton = {
        let button = createControlButton(
            image: "flashlight.off.fill",
            title: "闪光灯"
        )
        button.addTarget(self, action: #selector(torchButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var rescanButton: UIButton = {
        let button = createControlButton(
            image: "qrcode.viewfinder",
            title: "重新扫描"
        )
        button.addTarget(self, action: #selector(rescanButtonTapped), for: .touchUpInside)
        return button
    }()
    
    // MARK: - Initialization
    public init(viewModel: WDQRScannerViewModel = WDQRScannerViewModel()) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    open override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupBindings()
    }
    
    open override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = view.bounds
    }
    
    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel.startScanning()
    }
    
    open override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        viewModel.stopScanning()
    }
    
    // MARK: - UI Setup
    open func setupUI() {
        view.backgroundColor = .black
        view.layer.addSublayer(previewLayer)
        
        view.addSubview(scannerOverlay)
        view.addSubview(messageLabel)
        view.addSubview(controlStackView)
        
        controlStackView.addArrangedSubview(torchButton)
        controlStackView.addArrangedSubview(rescanButton)
        
        NSLayoutConstraint.activate([
            scannerOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            scannerOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scannerOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scannerOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            messageLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            messageLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            messageLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            messageLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20),
            
            controlStackView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -30),
            controlStackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }
    
    // MARK: - Bindings
    open func setupBindings() {
        
        viewModel.$scannerMessage
            .sink { [weak self] text in
                guard let self else { return }
                self.messageLabel.text = text
            }
            .store(in: &cancellables)
        
        viewModel.$isTorchEnabled
            .sink { [weak self] isEnabled in
                guard let self else { return }
                let imageName = isEnabled ? "flashlight.on.fill" : "flashlight.off.fill"
                self.torchButton.setImage(UIImage(systemName: imageName), for: .normal)
            }
            .store(in: &cancellables)
        
        viewModel.$alertMessage
            .sink { [weak self] message in
                guard let self, !message.isEmpty else { return }
                self.showAlert(message: message)
            }
            .store(in: &cancellables)
        
        viewModel.$scanResults
            .receive(on: DispatchQueue.main)
            .sink { [weak self] results in
                guard let self, let results else { return }
                self.handleScanResult(results)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Actions
    @objc private func torchButtonTapped() {
        viewModel.toggleTorch()
    }
    
    @objc private func rescanButtonTapped() {
        viewModel.startScanning()
        resetResultView()
    }
    
    private func resetResultView() {
        view.subviews.compactMap({ $0 as? _InnerResultButton }).forEach({ $0.removeFromSuperview() })
        resultBtnCancellables.forEach({ $0.cancel() })
        resultBtnCancellables = []
    }
    
    // MARK: - Helper Methods
    public func createControlButton(image: String, title: String) -> UIButton {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        
        let config = UIImage.SymbolConfiguration(pointSize: 25)
        button.setImage(UIImage(systemName: image, withConfiguration: config), for: .normal)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 12)
        button.tintColor = .white
        button.setTitleColor(.white, for: .normal)
        
        // 垂直布局
        button.centerTextAndImage(spacing: 8)
        
        return button
    }
    
    public func showAlert(message: String) {
        let alert = UIAlertController(
            title: "",
            message: message,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
    
    public func getImageFromSampleBuffer(sampleBuffer: CMSampleBuffer) -> UIImage? {
        let scale = UIScreen.main.scale
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        guard let context = CGContext(data: baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo.rawValue) else { return nil }
        guard let cgImage = context.makeImage() else { return nil }

        let sampleBuffer = UIImage(cgImage: cgImage, scale: scale, orientation: .up)
        CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)

        return readQRCode(sampleBuffer)
    }

    public func readQRCode(_ image: UIImage) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }
        let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
        guard let features = detector?.features(in: ciImage) else { return nil }
        guard let feature = features.first as? CIQRCodeFeature else { return nil }

        let transform = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -ciImage.extent.size.height)
        let path = UIBezierPath()
        path.move(to: feature.topLeft.applying(transform))
        path.addLine(to: feature.topRight.applying(transform))
        path.addLine(to: feature.bottomRight.applying(transform))
        path.addLine(to: feature.bottomLeft.applying(transform))
        path.close()
        return image.crop(path)
    }
    
    func handleScanResult(_ results: [WDQRScannerResult]) {
        guard !results.isEmpty else { return }
        
        resetResultView()
        
        if results.count == 1 {
            currentScanResult = results.first?.value
        }
        for (index, result) in results.enumerated() {
            if let object = previewLayer.transformedMetadataObject(for: result.metaObject) as? AVMetadataMachineReadableCodeObject {
                print(object.corners)
                let btn = _InnerResultButton()
                let config = UIImage.SymbolConfiguration(pointSize: 40)
                btn.setImage(UIImage(systemName: "arrow.right.circle", withConfiguration: config)?.withTintColor(.green), for: .normal)
                btn.tag = 100 + index
                btn.tintColor = .green
                btn.addTarget(self, action: #selector(scanResultButtonTapped(_:)), for: .touchUpInside)
                view.addSubview(btn)
                 
                let corners = object.corners
                // 计算 QR 码边界的中心点
                let centerX = corners.reduce(0) { $0 + $1.x } / CGFloat(corners.count)
                let centerY = corners.reduce(0) { $0 + $1.y } / CGFloat(corners.count)
                
                // 设置按钮大小和位置
                let buttonSize: CGFloat = 66
                btn.frame = CGRect(
                    x: centerX - buttonSize/2,
                    y: centerY - buttonSize/2,
                    width: buttonSize,
                    height: buttonSize
                )
            }
        }
    }
    
    @objc
    private func scanResultButtonTapped(_ sender: UIButton) {
        let index = sender.tag - 100
        guard index >= 0, index < (viewModel.scanResults?.count ?? 0) else { return }
        let result = viewModel.scanResults?[index]
        currentScanResult = result?.value
    }
}

class _InnerResultButton: UIButton {}

// MARK: - QRScannerOverlayView
final class QRScannerOverlayView: UIView {
    private let scannerFrame = CAShapeLayer()
    private let cornerLength: CGFloat = 20
    private let cornerWidth: CGFloat = 3
    private let scanLine = CAGradientLayer()
    private var scanLineAnimation: CABasicAnimation?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupOverlay()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateLayers()
    }
    
    private func setupOverlay() {
        backgroundColor = .clear
        
        // 设置扫描框角标
        scannerFrame.fillColor = nil
        scannerFrame.strokeColor = UIColor.white.cgColor
        scannerFrame.lineWidth = cornerWidth
        layer.addSublayer(scannerFrame)
        
        // 设置扫描线
        scanLine.colors = [
            UIColor.clear.cgColor,
            UIColor.white.cgColor,
            UIColor.clear.cgColor
        ]
        scanLine.startPoint = CGPoint(x: 0.5, y: 0.0)
        scanLine.endPoint = CGPoint(x: 0.5, y: 1.0)
        layer.addSublayer(scanLine)
        
        startScanLineAnimation()
    }
    
    private func updateLayers() {
        let size = min(bounds.width, bounds.height) * 0.7
        let scannerRect = CGRect(
            x: (bounds.width - size) / 2,
            y: (bounds.height - size) / 2,
            width: size,
            height: size
        )
        
        // 更新遮罩层
        let path = UIBezierPath(rect: bounds)
        path.append(UIBezierPath(rect: scannerRect).reversing())
        
        let maskLayer = CAShapeLayer()
        maskLayer.fillColor = UIColor.black.withAlphaComponent(0.5).cgColor
        maskLayer.fillRule = .evenOdd
        maskLayer.path = path.cgPath
        layer.mask = maskLayer
        
        // 更新扫描框角标
        let cornerPath = UIBezierPath()
        // 左上角
        cornerPath.move(to: CGPoint(x: scannerRect.minX, y: scannerRect.minY + cornerLength))
        cornerPath.addLine(to: CGPoint(x: scannerRect.minX, y: scannerRect.minY))
        cornerPath.addLine(to: CGPoint(x: scannerRect.minX + cornerLength, y: scannerRect.minY))
        
        // 右上角
        cornerPath.move(to: CGPoint(x: scannerRect.maxX - cornerLength, y: scannerRect.minY))
        cornerPath.addLine(to: CGPoint(x: scannerRect.maxX, y: scannerRect.minY))
        cornerPath.addLine(to: CGPoint(x: scannerRect.maxX, y: scannerRect.minY + cornerLength))
        
        // 右下角
        cornerPath.move(to: CGPoint(x: scannerRect.maxX, y: scannerRect.maxY - cornerLength))
        cornerPath.addLine(to: CGPoint(x: scannerRect.maxX, y: scannerRect.maxY))
        cornerPath.addLine(to: CGPoint(x: scannerRect.maxX - cornerLength, y: scannerRect.maxY))
        
        // 左下角
        cornerPath.move(to: CGPoint(x: scannerRect.minX + cornerLength, y: scannerRect.maxY))
        cornerPath.addLine(to: CGPoint(x: scannerRect.minX, y: scannerRect.maxY))
        cornerPath.addLine(to: CGPoint(x: scannerRect.minX, y: scannerRect.maxY - cornerLength))
        
        scannerFrame.path = cornerPath.cgPath
        
        // 更新扫描线
        scanLine.frame = CGRect(
            x: scannerRect.minX + 20,
            y: scannerRect.minY,
            width: scannerRect.width - 40,
            height: 2
        )
    }
    
    private func startScanLineAnimation() {
        let animation = CABasicAnimation(keyPath: "position.y")
        animation.fromValue = scanLine.position.y
        animation.toValue = bounds.height * 0.7
        animation.duration = 2.5
        animation.repeatCount = .infinity
        animation.isRemovedOnCompletion = false
        
        scanLine.add(animation, forKey: "scanLineAnimation")
        scanLineAnimation = animation
    }
}

// MARK: - UIButton Extension
extension UIButton {
    func centerTextAndImage(spacing: CGFloat) {
        guard let imageSize = imageView?.image?.size,
              let text = titleLabel?.text,
              let font = titleLabel?.font else { return }
        
        let titleSize = text.size(withAttributes: [.font: font])
        
        let totalHeight = imageSize.height + spacing + titleSize.height
        
        imageEdgeInsets = UIEdgeInsets(
            top: -(totalHeight - imageSize.height),
            left: 0,
            bottom: 0,
            right: -titleSize.width
        )
        
        titleEdgeInsets = UIEdgeInsets(
            top: 0,
            left: -imageSize.width,
            bottom: -(totalHeight - titleSize.height),
            right: 0
        )
    }
}

// MARK: - UILabel Extension
extension UILabel {
    var padding: UIEdgeInsets {
        get {
            return .zero
        }
        set {
            let paddingView = UIView()
            paddingView.translatesAutoresizingMaskIntoConstraints = false
            
            self.addSubview(paddingView)
            
            NSLayoutConstraint.activate([
                paddingView.topAnchor.constraint(equalTo: self.topAnchor, constant: -newValue.top),
                paddingView.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: newValue.bottom),
                paddingView.leftAnchor.constraint(equalTo: self.leftAnchor, constant: -newValue.left),
                paddingView.rightAnchor.constraint(equalTo: self.rightAnchor, constant: newValue.right),
            ])
        }
    }
}

private extension UIImage {
    func crop(_ path: UIBezierPath) -> UIImage? {
        let rect = CGRect(origin: CGPoint(), size: CGSize(width: size.width * scale, height: size.height * scale))
        UIGraphicsBeginImageContextWithOptions(rect.size, false, scale)

        UIColor.clear.setFill()
        UIRectFill(rect)
        path.addClip()
        draw(in: rect)

        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        guard let croppedImage = image?.cgImage?.cropping(to: CGRect(x: path.bounds.origin.x * scale, y: path.bounds.origin.y * scale, width: path.bounds.size.width * scale, height: path.bounds.size.height * scale)) else { return nil }
        return UIImage(cgImage: croppedImage, scale: scale, orientation: imageOrientation)
    }
}
