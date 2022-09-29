//
//  MovieViewController.swift
//  XCrema
//
//  Created by ByteDance on 2022/9/26.
//

import UIKit
import AVFoundation
import SnapKit
import RxSwift
import RxCocoa
import Photos

class MovieViewController: UIViewController {

    let disposeBag = DisposeBag()

    let session = AVCaptureSession()

    private let videoDevice = AVCaptureDevice.default(for: AVMediaType.video)
    private let audioDevice = AVCaptureDevice.default(for: AVMediaType.audio)

    /// 图像预览层，实时显示捕获的图像
    var previewLayer: AVCaptureVideoPreviewLayer?

    /// 视频输出流
    let movieOutput = AVCaptureMovieFileOutput()

    var flashMode = AVCaptureDevice.FlashMode.off

    var isRecording: Bool = false

    /// 记录开始的缩放比例
    var beginGestureScale: CGFloat = 1.0
    /// 最后的缩放比例
    var effectiveScale: CGFloat = 1.0

    var outputURL: URL?

    // 计时器
    var seconds = 0
    var timer = Timer()

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

    private let toggleModeButton: UIButton = {
        let button = UIButton()
        button.setImage(UIImage(named: "camera"), for: .normal)
        return button
    }()

    private let recordButton: UIButton = {
        let button = UIButton()
        button.setImage(UIImage(named: "record_start"), for: .normal)
        return button
    }()

    private let timeLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor.white
        label.font = UIFont.systemFont(ofSize: 20)
        label.textAlignment = .center
        return label
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
            guard let self = self,
                  let videoDevice = self.videoDevice else { return }
            try? videoDevice.lockForConfiguration()
            if self.flashMode == .on {
                self.flashMode = .off
                self.flashButton.setImage(UIImage(named: "flash_off"), for: .normal)
                videoDevice.torchMode = .off
            } else if self.flashMode == .off {
                self.flashMode = .on
                self.flashButton.setImage(UIImage(named: "flash_on"), for: .normal)
                videoDevice.torchMode = .on
            }
            videoDevice.unlockForConfiguration()
        }).disposed(by: self.disposeBag)

        headerView.addSubview(toggleModeButton)
        toggleModeButton.snp.makeConstraints { make in
            make.width.equalTo(32)
            make.height.equalTo(32)
            make.centerY.equalTo(flashButton)
            make.right.equalToSuperview().offset(-40)
        }
        toggleModeButton.rx.tap.subscribe(onNext: { [weak self] () in
            guard let self = self else { return }
            let vc = PhotoViewController()
            self.navigationController?.pushViewController(vc, animated: true)
            if let count = self.navigationController?.viewControllers.count {
                self.navigationController?.viewControllers.remove(at: count - 2)
            }
        }).disposed(by: self.disposeBag)

        timeLabel.text = timeString(time: TimeInterval(seconds))
        headerView.addSubview(timeLabel)
        timeLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalTo(flashButton)
        }
    }

    func setupBottomView() {
        self.view.addSubview(bottomView)
        bottomView.snp.makeConstraints { make in
            make.bottom.equalToSuperview()
            make.height.equalTo(150)
            make.left.right.equalToSuperview()
        }

        bottomView.addSubview(recordButton)
        recordButton.snp.makeConstraints { make in
            make.width.height.equalTo(68)
            make.top.equalToSuperview().offset(20)
            make.centerX.equalToSuperview()
        }
        recordButton.rx.tap.subscribe(onNext: { [weak self] () in
            guard let self = self else { return }
            if self.isRecording {
                self.movieOutput.stopRecording()
                self.isRecording = false
                self.recordButton.setImage(UIImage(named: "record_start"), for: .normal)
                self.flashButton.isHidden = false
                self.timer.invalidate()
                self.seconds = 0
                self.timeLabel.text = self.timeString(time: TimeInterval(self.seconds))
            } else {
                // 设置目录的保存地址
                let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
                let documentDict: String = paths[0]
                let filePath = "\(documentDict)/movie.mov"
                let fileUrl = URL(fileURLWithPath: filePath)
                self.outputURL = fileUrl
                print("outputURL: \(self.outputURL!)")
                self.movieOutput.startRecording(to: self.outputURL!, recordingDelegate: self)
                self.isRecording = true
                self.recordButton.setImage(UIImage(named: "record_stop"), for: .normal)
                self.flashButton.isHidden = true
                self.runTimer()
            }
        }).disposed(by: self.disposeBag)
    }

    @objc func updateTimer() {
        seconds += 1
        timeLabel.text = timeString(time: TimeInterval(seconds))
    }

    func runTimer() {
        timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: (#selector(MovieViewController.updateTimer)), userInfo: nil, repeats: true)
    }

    func timeString(time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = Int(time) / 60 % 60
        let seconds = Int(time) % 60
        return String(format:"%02i:%02i:%02i", hours, minutes, seconds)
    }
}

extension MovieViewController {
    /// 启动相机
    func startCamera() {
        self.isRecording = false
        if let videoDevice = self.videoDevice {
           let videoInput = try! AVCaptureDeviceInput(device: videoDevice)
            if session.canAddInput(videoInput) {
                session.addInput(videoInput)
            }
        }
        if let audioDevice = self.audioDevice {
           let audioInput = try! AVCaptureDeviceInput(device: audioDevice)
            if session.canAddInput(audioInput) {
                session.addInput(audioInput)
            }
        }
        if session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
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
    }

    @objc
    private func focusGesture(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: gesture.view)
        focusAtPoint(point: point)
    }

    private func focusAtPoint(point: CGPoint) {
        let size = self.view.bounds.size
        let focusPoint = CGPoint(x: point.y / size.height, y: 1 - point.x / size.width)
        guard let captureDevice = self.videoDevice else { return }
        try? captureDevice.lockForConfiguration()
        if captureDevice.isFocusModeSupported(.autoFocus) {
            captureDevice.focusPointOfInterest = focusPoint
            captureDevice.focusMode = .autoFocus
        }
        if captureDevice.isExposureModeSupported(.autoExpose) {
            captureDevice.exposurePointOfInterest = focusPoint
            captureDevice.exposureMode = .autoExpose
        }
        captureDevice.unlockForConfiguration()
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
}

extension MovieViewController: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error = error {
            print("error: \(error)")
        }
        try? PHPhotoLibrary.shared().performChangesAndWait {
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outputFileURL)
        }
    }
}
