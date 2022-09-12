//
//  ViewController.swift
//  XCrema
//
//  Created by ByteDance on 2022/9/2.
//

import UIKit
import AVFoundation

class ViewController: UIViewController, AVCapturePhotoCaptureDelegate {

    enum CameraPosition {
        case back
        case front
    }

    let session = AVCaptureSession()

    private var currentCameraPosition: CameraPosition?

    private var frontCamera: AVCaptureDevice?
    private var backCamera: AVCaptureDevice?
    private var frontCameraInput: AVCaptureDeviceInput?
    private var backCameraInput: AVCaptureDeviceInput?

    let photoOutput = AVCapturePhotoOutput()

    override var shouldAutorotate: Bool {
        return false
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
        self.startCamera()
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
        let videoLayer = AVCaptureVideoPreviewLayer(session: session)
        videoLayer.videoGravity = .resizeAspectFill
        videoLayer.frame = self.view.frame
        self.view.layer.masksToBounds = true
        self.view.layer.addSublayer(videoLayer)
    }
}

