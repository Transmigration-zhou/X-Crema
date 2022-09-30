//
//  PhotoBrowserViewController.swift
//  XCrema
//
//  Created by ByteDance on 2022/9/30.
//

import UIKit

class PhotoBrowserViewController: UIViewController {

    private var scrollView: UIScrollView!
    private var imageView: UIImageView!

    init(image: UIImage) {
        super.init(nibName: nil, bundle: nil)
        self.imageView = UIImageView(image: image)
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
        let bgView = UIScrollView.init(frame: self.view.bounds)
        bgView.backgroundColor = .black
        bgView.addSubview(self.imageView)
        self.view.addSubview(bgView)
        self.scrollView = bgView
        self.scrollView.maximumZoomScale = 2.0
        self.scrollView.delegate = self

        var frame = self.imageView.frame
        frame.size.width = bgView.frame.size.width
        guard let image = self.imageView.image,
              image.size.width > 0,
              image.size.height > 0 else { return }
        frame.size.height = frame.size.width * (image.size.height / image.size.width)
        frame.origin.x = 0
        frame.origin.y = (bgView.frame.size.height - frame.size.height) * 0.3
        self.imageView.frame = frame
    }
}

extension PhotoBrowserViewController: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return self.imageView
    }
}
