//
//  PhotoViewController.swift
//  XCrema
//
//  Created by ByteDance on 2022/9/2.
//

import UIKit
import AVFoundation
import SnapKit
import RxSwift
import RxCocoa
import Photos

class PhotoViewController: UIViewController {

    enum CameraPosition {
        case back
        case front
    }

    let disposeBag = DisposeBag()

    let session = AVCaptureSession()

    private var currentCameraPosition: CameraPosition?

    private var frontCamera: AVCaptureDevice?
    private var backCamera: AVCaptureDevice?
    private var frontCameraInput: AVCaptureDeviceInput?
    private var backCameraInput: AVCaptureDeviceInput?

    /// 图像预览层，实时显示捕获的图像
    var previewLayer: AVCaptureVideoPreviewLayer?

    /// 照片输出流
    let photoOutput = AVCapturePhotoOutput()

    var flashMode = AVCaptureDevice.FlashMode.off

    /// 记录开始的缩放比例
    var beginGestureScale: CGFloat = 1.0
    /// 最后的缩放比例
    var effectiveScale: CGFloat = 1.0

    private let headerView: UIView = {
        let view = UIView()
        view.backgroundColor = .black.withAlphaComponent(0.4)
        return view
    }()

    private let bottomView: UIView = {
        let view = UIView()
        view.backgroundColor = .black.withAlphaComponent(0.4)
        return view
    }()

    private let focusView: UIView = {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 80, height: 80))
        view.layer.borderWidth = 1.0
        view.layer.borderColor = UIColor.green.cgColor
        view.backgroundColor = .clear
        view.isHidden = true
        return view
    }()

    private let flashButton: UIButton = {
        let button = UIButton()
        button.setImage(UIImage(named: "flash_off"), for: .normal)
        return button
    }()

    private let captureButton: UIButton = {
        let button = UIButton()
        button.setImage(UIImage(named: "capture"), for: .normal)
        return button
    }()

    private let toggleCameraButton: UIButton = {
        let button = UIButton()
        button.setImage(UIImage(named: "toggleCamera"), for: .normal)
        return button
    }()

    override var shouldAutorotate: Bool {
        return false
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
        self.startCamera()
        self.setupHeaderView()
        self.setupBottomView()
        self.addTapGesture()
    }

    func setupHeaderView() {
        self.view.addSubview(headerView)
        headerView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.height.equalTo(100)
            make.left.right.equalToSuperview()
        }

        headerView.addSubview(flashButton)
        flashButton.snp.makeConstraints { make in
            make.width.equalTo(13)
            make.height.equalTo(21)
            make.bottom.equalToSuperview().offset(-20)
            make.left.equalToSuperview().offset(40)
        }
        flashButton.rx.tap.subscribe(onNext: { [weak self] () in
            guard let self = self else { return }
            if self.flashMode == .on {
                self.flashMode = .off
                self.flashButton.setImage(UIImage(named: "flash_off"), for: .normal)
            } else if self.flashMode == .off {
                self.flashMode = .on
                self.flashButton.setImage(UIImage(named: "flash_on"), for: .normal)
            }
        }).disposed(by: self.disposeBag)
    }

    func setupBottomView() {
        self.view.addSubview(bottomView)
        bottomView.snp.makeConstraints { make in
            make.bottom.equalToSuperview()
            make.height.equalTo(150)
            make.left.right.equalToSuperview()
        }

        bottomView.addSubview(captureButton)
        captureButton.snp.makeConstraints { make in
            make.width.height.equalTo(68)
            make.top.equalToSuperview().offset(20)
            make.centerX.equalToSuperview()
        }
        captureButton.rx.tap.subscribe(onNext: { [weak self] () in
            guard let self = self else { return }
            let connection = self.photoOutput.connection(with: .video)
            connection?.videoScaleAndCropFactor = self.effectiveScale
            let settings = AVCapturePhotoSettings()
            settings.flashMode = self.flashMode
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }).disposed(by: self.disposeBag)

        self.bottomView.addSubview(toggleCameraButton)
        toggleCameraButton.snp.makeConstraints { make in
            make.width.equalTo(30)
            make.height.equalTo(23)
            make.centerY.equalTo(captureButton)
            make.right.equalToSuperview().offset(-60)
        }
        toggleCameraButton.rx.tap.subscribe(onNext: { [weak self] () in
            guard let self = self,
                  let currentCameraPosition = self.currentCameraPosition,
                  self.session.isRunning else { return }
            self.session.beginConfiguration()
            switch currentCameraPosition {
            case .front:
                guard let backCamera = self.backCamera else { return }
                self.backCameraInput = try! AVCaptureDeviceInput(device: backCamera)
                self.session.removeInput(self.frontCameraInput!)
                if self.session.canAddInput(self.backCameraInput!) {
                    self.session.addInput(self.backCameraInput!)
                }
                self.currentCameraPosition = .back
            case .back:
                guard let frontCamera = self.frontCamera else { return }
                self.frontCameraInput = try! AVCaptureDeviceInput(device: frontCamera)
                self.session.removeInput(self.backCameraInput!)
                if self.session.canAddInput(self.frontCameraInput!) {
                    self.session.addInput(self.frontCameraInput!)
                }
                self.currentCameraPosition = .front
            }
            self.session.commitConfiguration()
            self.effectiveScale = 1.0
            let connection = self.photoOutput.connection(with: .video)
            connection?.videoScaleAndCropFactor = self.effectiveScale
            self.previewLayer?.setAffineTransform(CGAffineTransform(scaleX: self.effectiveScale, y: self.effectiveScale))
        }).disposed(by: self.disposeBag)
    }
}

extension PhotoViewController {
    /// 启动相机
    func startCamera() {
        let cameras = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: AVMediaType.video, position: .unspecified).devices.compactMap { $0 }

        for camera in cameras {
            if camera.position == .back {
                self.backCamera = camera
            } else if camera.position == .front {
                self.frontCamera = camera
            }
        }
        // 默认后置摄像头
        if let backCamera = self.backCamera {
            backCameraInput = try! AVCaptureDeviceInput(device: backCamera)
            if session.canAddInput(backCameraInput!) {
                session.addInput(backCameraInput!)
            }
            self.currentCameraPosition = .back
        } else if let frontCamera = self.frontCamera {
            frontCameraInput = try! AVCaptureDeviceInput(device: frontCamera)
            if session.canAddInput(frontCameraInput!) {
                session.addInput(frontCameraInput!)
            }
            self.currentCameraPosition = .front
        }
        self.photoOutput.setPreparedPhotoSettingsArray([AVCapturePhotoSettings(format: [AVVideoCodecKey : AVVideoCodecType.jpeg])], completionHandler: nil)
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }
        session.startRunning()
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer?.videoGravity = .resizeAspectFill
        previewLayer?.frame = self.view.frame
        self.view.layer.addSublayer(previewLayer!)
    }

    /// 添加手势
    func addTapGesture() {
        // 点击屏幕对焦
        self.view.addSubview(focusView)
        let tap = UITapGestureRecognizer(target: self, action: #selector(focusGesture(_:)))
        self.view.addGestureRecognizer(tap)
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinchGesture(_:)))
        pinch.delegate = self
        self.view.addGestureRecognizer(pinch)
    }

    @objc
    private func focusGesture(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: gesture.view)
        focusAtPoint(point: point)
    }

    private func focusAtPoint(point: CGPoint) {
        let size = self.view.bounds.size
        let focusPoint = CGPoint(x: point.y / size.height, y: 1 - point.x / size.width)
        guard let currentCameraPosition = self.currentCameraPosition else { return }
        let currentCamera = currentCameraPosition == .back ? backCamera : frontCamera
        guard let captureDevice = currentCamera else { return }
        do {
            try captureDevice.lockForConfiguration()
            if captureDevice.isFocusModeSupported(.autoFocus) {
                captureDevice.focusPointOfInterest = focusPoint
                captureDevice.focusMode = .autoFocus
            }
            if captureDevice.isExposureModeSupported(.autoExpose) {
                captureDevice.exposurePointOfInterest = focusPoint
                captureDevice.exposureMode = .autoExpose
            }
            captureDevice.unlockForConfiguration()
        } catch {
        }

        self.focusView.center = point
        self.focusView.isHidden = false
        UIView.animate(withDuration: 0.3, animations: { [weak self] in
            self?.focusView.transform = CGAffineTransform(scaleX: 1.25, y: 1.25)
        }) { [weak self] _ in
            UIView.animate(withDuration: 0.5, animations: { [weak self] in
                self?.focusView.transform = CGAffineTransform.identity
            }) { [weak self] _ in
                self?.focusView.isHidden = true
            }
        }
    }

    @objc
    func handlePinchGesture(_ recognizer: UIPinchGestureRecognizer) {
        var allTouchesAreOnThePreviewLayer = true
        let numTouches = recognizer.numberOfTouches
        for i in 0..<numTouches {
            let location = recognizer.location(ofTouch: i, in: self.view)
            let convertedLocation = previewLayer?.convert(location, from: previewLayer?.superlayer)
            if !(previewLayer?.contains(convertedLocation!))! {
                allTouchesAreOnThePreviewLayer = false
                break
            }
        }
        if allTouchesAreOnThePreviewLayer {
            self.effectiveScale = self.beginGestureScale * recognizer.scale
            if self.effectiveScale < 1.0 {
                self.effectiveScale = 1.0
            }
            let maxScaleAndCropFactor = photoOutput.connection(with: .video)?.videoMaxScaleAndCropFactor
            if self.effectiveScale > maxScaleAndCropFactor! {
                self.effectiveScale = maxScaleAndCropFactor!
            }
            UIView.animate(withDuration: 0.025) {
                self.previewLayer?.setAffineTransform(CGAffineTransform(scaleX: self.effectiveScale, y: self.effectiveScale))
            }
        }
    }
}

extension PhotoViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("error: \(error)")
        }
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else { return }
        try? PHPhotoLibrary.shared().performChangesAndWait {
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }
    }
}

extension PhotoViewController: UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer is UIPinchGestureRecognizer {
            self.beginGestureScale = self.effectiveScale
        }
        return true
    }
}
