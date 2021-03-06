//
//  FirstViewController.swift
//  Pirate
//
//  Created by hyperorchid on 2020/2/15.
//  Copyright © 2020 hyperorchid. All rights reserved.
//

import UIKit
import NetworkExtension
import web3swift

extension NEVPNStatus: CustomStringConvertible {
    public var description: String {
        switch self {
        case .disconnected: return "Disconnected".locStr
                case .invalid: return "Invalid".locStr
                case .connected: return "Connected".locStr
                case .connecting: return "Connecting".locStr
                case .disconnecting: return "Disconnecting".locStr
                case .reasserting: return "Reconnecting".locStr
        @unknown default:
                return "unknown".locStr
        }
    }
}

class HomeVC: UIViewController {
        @IBOutlet weak var connectButton: UIButton!
        @IBOutlet weak var vpnStatusLabel: UILabel!
        @IBOutlet weak var minersIDLabel: UILabel!
        @IBOutlet weak var minersIPLabel: UILabel!
        @IBOutlet weak var creditPacketLabel: UILabel!
        @IBOutlet weak var CurMinerLabel: UILabel!
        @IBOutlet weak var packetBalanceLabel: UILabel!
        @IBOutlet weak var curPoolLabel: UILabel!
        @IBOutlet weak var poolAddrLabel: UILabel!
        @IBOutlet weak var globalModelSeg: UISegmentedControl!
        
        var rcpWire:RcpWire?
        var vpnStatusOn:Bool = false
        var targetManager:NETunnelProviderManager? = nil
        
        override func viewDidLoad() {
                super.viewDidLoad()
                reloadManagers()
                let img = UIImage(named: "bg_image")!
                self.view.backgroundColor = UIColor(patternImage: img)
                NotificationCenter.default.addObserver(self, selector: #selector(VPNStatusDidChange(_:)), name: NSNotification.Name.NEVPNStatusDidChange, object: nil)
                NotificationCenter.default.addObserver(self, selector: #selector(SettingChanged(_:)), name: HopConstants.NOTI_LOCAL_SETTING_CHANGED, object: nil)
                NotificationCenter.default.addObserver(self, selector: #selector(PoolChanged(_:)), name: HopConstants.NOTI_CHANGE_POOL, object: nil)
                NotificationCenter.default.addObserver(self, selector: #selector(MinerChanged(_:)), name: HopConstants.NOTI_CHANGE_MINER, object: nil)
        }
        
        override func viewWillAppear(_ animated: Bool) {
                super.viewWillAppear(animated)
                setPoolMiners()
        }
        // MARK:  UI Action
        @IBAction func startOrStop(_ sender: Any) {
                
                guard let conn = self.targetManager?.connection else{
                        reloadManagers()
                        return
                }
                
                guard conn.status == .disconnected || conn.status == .invalid else {
                        conn.stopVPNTunnel()
                        return
                }
                
                guard let pool = DataSyncer.sharedInstance.localSetting?.poolInUse else {
                        self.ShowTips(msg: "Choose your pool first".locStr)
                        return
                }
                guard let miner = DataSyncer.sharedInstance.localSetting?.minerInUse else {
                        self.ShowTips(msg: "Choose your node first".locStr)
                        return
                }
                
                guard let w = DataSyncer.sharedInstance.wallet else{
                       self.ShowTips(msg: "Create a account first".locStr)
                       return
                }
               
                guard  w.IsOpen() else{

                        self.showIndicator(withTitle: "Account".locStr, and: "Open Account".locStr)
                        self.ShowPassword() { (password, isOK) in
                                if password == nil || isOK == false{
                                        self.hideIndicator()
                                       return
                                }
                                do {
                                        try w.Open(auth: password!)
                                        self.hideIndicator()
                                        try self._startVPN(wallet: w, pool: pool, miner: miner)
                                }catch let err{
                                        self.hideIndicator()
                                        self.ShowTips(msg: err.localizedDescription)
                                }
                        }
                        return
                }
                
                do {
                        try self._startVPN(wallet: w, pool: pool, miner: miner)
                }catch let err{
                        NSLog("=======>Failed to start the VPN: \(err)")
                        self.ShowTips(msg: err.localizedDescription)
                }
        }
        
        private func _startVPN(wallet w:HopWallet, pool:String, miner:String) throws{
                
                self.showIndicator(withTitle: "VPN", and: "Starting VPN".locStr)
                
                let options = ["HOP_ADDR":HopConstants.DefaultTokenAddr,
                               "MPC_ADDR":HopConstants.DefaultPaymenstService,
                               "ROUTE_RULES": Utils.Domains["CN"] as Any,
                               "MAIN_PRI":w.privateKey?.mainPriKey as Any,
                               "SUB_PRI":w.privateKey?.subPriKey as Any,
                               "POOL_ADDR":pool as Any,
                               "USER_ADDR":w.mainAddress?.address as Any,
                               "USER_SUB_ADDR":w.subAddress! as Any,
                               "GLOBAL_MODE":DataSyncer.isGlobalModel,
                               "MINER_ADDR":miner as Any]
                        as! [String : NSObject]
                
                try self.targetManager!.connection.startVPNTunnel(options: options)
        }
        
        @objc func VPNStatusDidChange(_ notification: Notification?) {
                
                defer {
                        if self.vpnStatusOn{
                                connectButton.setBackgroundImage(UIImage.init(named: "Con_icon"), for: .normal)
                        }else{
                                connectButton.setBackgroundImage(UIImage.init(named: "Dis_butt"), for: .normal)
                        }
                }
                
                guard  let status = self.targetManager?.connection.status else{
                        return
                }
                
                NSLog("=======>VPN Status changed:[\(status.description)]")
                self.vpnStatusLabel.text = status.description
                self.vpnStatusOn = status == .connected
                if status == .invalid{
                        self.targetManager?.loadFromPreferences(){
                                err in
                                NSLog("=======>VPN loadFromPreferences [\(err?.localizedDescription  ?? "Success" )]")
                        }
                }
                
                if status == .connected || status == .disconnected{
                        self.hideIndicator()
                }
        }
        
        @objc func SettingChanged(_ notification: Notification?) {
                if self.vpnStatusOn{
                        self.targetManager?.connection.stopVPNTunnel()
                }
        }
        
        private func setPoolMiners(){
                
                let pool = DataSyncer.sharedInstance.localSetting?.poolInUse
                if pool != nil{
                        let p_data = DataSyncer.sharedInstance.poolData[pool!]
                        self.curPoolLabel.text = "\(p_data?.ShortName ?? "")"
                        self.poolAddrLabel.text = pool
                        let u_acc = PacketAccountant.Inst.accountant(ofPool:pool!)
                        self.packetBalanceLabel.text = u_acc?.packetBalance.ToPackets()
                        self.creditPacketLabel.text = u_acc?.credit.ToPackets()
                        
                }else{
                        self.curPoolLabel.text = "NAN".locStr
                        self.poolAddrLabel.text = ""
                }
                
                let miner = DataSyncer.sharedInstance.localSetting?.minerInUse
                if miner != nil {
                        let m_data = MinerData.MinerDetailsDic[miner!]
                        self.CurMinerLabel.text = "\(m_data?.Zone ?? "")"
                        self.minersIDLabel.text = m_data?.Address
                        self.minersIPLabel.text = m_data?.IP ?? "NAN".locStr
                }else{
                        self.CurMinerLabel.text = "NAN".locStr
                        self.minersIDLabel.text = ""
                        self.minersIPLabel.text = ""
                }
        }
        
        @IBAction func changeModel(_ sender: UISegmentedControl) {
                let old_model = DataSyncer.isGlobalModel
                
                switch sender.selectedSegmentIndex{
                        case 0:
                                DataSyncer.isGlobalModel = false
                        case 1:
                                DataSyncer.isGlobalModel = true
                default:
                        DataSyncer.isGlobalModel = false
                }
                
                self.notifyModelToVPN(sender:sender, oldStatus:old_model)
        }
        
        @IBAction func ShowPoolChooseView(_ sender: Any) {
                self.performSegue(withIdentifier: "ChoosePoolsViewControllerSS", sender: self)
        }
        
        @IBAction func ShowMinerChooseView(_ sender: Any) {
                
                guard DataSyncer.sharedInstance.localSetting?.poolInUse != nil else {
                        self.ShowTips(msg: "Choose your pool first".locStr)
                        return
                }
                
                self.performSegue(withIdentifier: "ChooseMinersViewControllerSS", sender: self)
        }
        
        func setModelStatus(sender: UISegmentedControl, oldStatus:Bool){
                DispatchQueue.main.async {
                        if oldStatus{
                                sender.selectedSegmentIndex = 1
                        }else{
                                sender.selectedSegmentIndex = 0
                        }
                }
        }
        
        // MARK: - VPN Manager
        func reloadManagers() {
                NETunnelProviderManager.loadAllFromPreferences() { newManagers, error in
                        if let err = error {
                                NSLog(err.localizedDescription)
                                return
                        }
                        
                        guard let vpnManagers = newManagers else { return }

                        NSLog("=======>vpnManager=\(vpnManagers.count)")
                        if vpnManagers.count > 0{
                                self.targetManager = vpnManagers[0]
                                self.getModelFromVPN()
                        }else{
                                self.targetManager = NETunnelProviderManager()
                        }
                        
                        self.targetManager?.loadFromPreferences(completionHandler: { err in
                                if let err = error {
                                        NSLog(err.localizedDescription)
                                        return
                                }
                                self.setupVPN()
                        })
                }
        }
        
        func setupVPN(){
                
                targetManager?.localizedDescription = "Hyper Orchid Protocol".locStr
                targetManager?.isEnabled = true
                
                let providerProtocol = NETunnelProviderProtocol()
                let cur_ser = DataSyncer.sharedInstance.localSetting?.poolInUse ?? "no pool".locStr
                providerProtocol.serverAddress = cur_ser
                targetManager?.protocolConfiguration = providerProtocol
                
                targetManager?.saveToPreferences { err in
                        if let saveErr = err{
                                NSLog("save preference err:\(saveErr.localizedDescription)")
                                return
                        }
                        self.VPNStatusDidChange(nil)
                }
        }
        
        private func getModelFromVPN(){
                guard let session = self.targetManager?.connection as? NETunnelProviderSession,
                        session.status != .invalid else{
                                NSLog("=======>Can't not load global model")
                                return
                }
                
                NSLog("=======>VPN is on and need to load global model")
                let message = NSKeyedArchiver.archivedData(withRootObject: ["GetModel": true])
                try? session.sendProviderMessage(message, responseHandler: {reponse in
                        guard let r = reponse else{
                                return
                        }
                        guard let param = NSKeyedUnarchiver.unarchiveObject(with: r) as? [String:Any],
                        let is_global = param["Global"] as? Bool, is_global == true else{
                                DataSyncer.isGlobalModel = false
                                self.setModelStatus(sender: self.globalModelSeg, oldStatus: false)
                                NSLog("=======>Curretn global model is false")
                                return
                        }

                        NSLog("=======>Curretn global model is true")
                        DataSyncer.isGlobalModel = true
                        self.setModelStatus(sender: self.globalModelSeg, oldStatus: true)
                })
        }
        
        private func notifyModelToVPN(sender: UISegmentedControl, oldStatus:Bool){
                
                guard self.vpnStatusOn == true,
                        let session = self.targetManager?.connection as? NETunnelProviderSession,
                        session.status != .invalid else{
                                return
                }
                
                let message = NSKeyedArchiver.archivedData(withRootObject: ["Global": DataSyncer.isGlobalModel])
                do{
                        try session.sendProviderMessage(message, responseHandler: {reponse in
                                if reponse != nil{
                                        NSLog(String(data: reponse!, encoding: .utf8)!)
                                }
                        })
                        
                }catch let err{
                        self.setModelStatus(sender: sender, oldStatus: oldStatus)
                        self.ShowTips(msg: err.localizedDescription)
                }
        }
        
        // MARK - miner or pool changed
        @objc func PoolChanged(_ notification: Notification?) {
                let new_pool = notification?.userInfo?["New_Pool"] as? String
                DataSyncer.sharedInstance.localSetting?.poolInUse = new_pool
                DataSyncer.sharedInstance.localSetting?.minerInUse = ""
                MinerData.MinerDetailsDic.removeAll()
                DataShareManager.saveContext(DataSyncer.sharedInstance.dbContext)
                if self.targetManager?.connection.status == .connected{
                        self.targetManager?.connection.stopVPNTunnel()
                }
                
                setPoolMiners()
        }
        
        @objc func MinerChanged(_ notification: Notification?)  {
                let new_miner = notification?.userInfo?["New_Miner"] as? String                
                DataSyncer.sharedInstance.localSetting?.minerInUse = new_miner
                DataShareManager.saveContext(DataSyncer.sharedInstance.dbContext)
                
                if self.targetManager?.connection.status == .connected{
                        self.targetManager?.connection.stopVPNTunnel()
                }
                setPoolMiners()
        }
}
