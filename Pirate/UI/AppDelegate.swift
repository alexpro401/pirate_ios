//
//  AppDelegate.swift
//  Pirate
//
//  Created by hyperorchid on 2020/2/15.
//  Copyright © 2020 hyperorchid. All rights reserved.
//

import UIKit
import CoreData

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
        public static var SyncTimer = TimeInterval(60)
        var timer:Timer?
        
        var window: UIWindow?
        func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
                
                Utils.initDomains()
                _ = HopSodium.initialized
                var erc20 = DataSyncer.sharedInstance.localSetting?.tokenAddrInUse
                if erc20 == nil{
                        erc20 = HopConstants.DefaultTokenAddr
                }
                var mpc = DataSyncer.sharedInstance.localSetting?.contractAddress
                if mpc == nil{
                        mpc = HopConstants.DefaultPaymenstService
                }
                
                do {try EthUtil.sharedInstance.initEth(ERC20: erc20!,
                                                   Contract: mpc!,
                                                   infura:nil,
                                                   testNet:nil)
                        
                }catch let err{
                        NSLog(err.localizedDescription)
                        return false
                }
                
                return true
        }

        // MARK: UISceneSession Lifecycle

        @available(iOS 13.0, *)
        func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
                return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        }
        @available(iOS 13.0, *)
        func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        }

        func applicationDidBecomeActive(_ application: UIApplication) {
                DataSyncer.EthVersionCheck()
                DispatchQueue.main.async {
                        NSLog("=======>timer init--->")
                        self.timer = Timer.scheduledTimer(withTimeInterval:
                        AppDelegate.SyncTimer, repeats: true) {
                                (time) in
                                DataSyncer.EthVersionCheck() 
                }}
        }
        
        func applicationDidEnterBackground(_ application: UIApplication) {
                NSLog("=======>timer invalidate--->")
                self.timer?.invalidate()
        }
        
        func applicationWillTerminate(_ application: UIApplication) {
                NSLog("=======>will save all data--->")
                let context = DataShareManager.privateQueueContext()
                DataShareManager.saveContext(context)
                DataShareManager.syncAllContext(context)
        }
}
