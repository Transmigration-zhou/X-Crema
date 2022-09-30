//
//  AppDelegate.swift
//  XCrema
//
//  Created by ByteDance on 2022/9/2.
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        self.window = UIWindow(frame: UIScreen.main.bounds)
        let vc = PhotoViewController()
        let mainVC = UINavigationController(rootViewController: vc)
        mainVC.navigationBar.isHidden = true
        self.window?.rootViewController = mainVC
        self.window?.makeKeyAndVisible()
        return true
    }


}

