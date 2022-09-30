//
//  MoviePlayerViewController.swift
//  XCrema
//
//  Created by ByteDance on 2022/9/30.
//

import UIKit
import AVFoundation

class MoviePlayerViewController: UIViewController {

    private var player: AVPlayer!

    private var displayView: UIView!

    
    init(url: URL) {
        super.init(nibName: nil, bundle: nil)
        self.player = AVPlayer(url: url)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        self.setupUI()
    }

    func setupUI() {
        self.displayView = UIView(frame: self.view.bounds)
        self.view.addSubview(self.displayView)
        let playerLayer = AVPlayerLayer(player: self.player)
        playerLayer.frame = self.displayView.frame
        self.displayView.layer.addSublayer(playerLayer)
    }
}
