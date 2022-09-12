//
//  ViewController.swift
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

class ViewController: UIViewController, AVCapturePhotoCaptureDelegate {

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

    let photoOutput = AVCapturePhotoOutput()

    var flashMode = AVCaptureDevice.FlashMode.off

    private let cameraView: UIView = {
        let view = UIView()
        return view
    }()

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
        }).disposed(by: self.disposeBag)
    }

    func setupCameraView() {
        self.view.addSubview(cameraView)
        cameraView.snp.makeConstraints { make in
            make.top.equalTo(headerView.snp.bottom)
            make.bottom.equalTo(bottomView.snp.top)
            make.left.right.equalToSuperview()
        }
    }

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
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = self.view.frame
        self.view.layer.addSublayer(previewLayer)
    }

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

