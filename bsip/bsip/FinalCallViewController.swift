//
//  AudioTestViewController.swift
//  bsip
//
//  Created by wesley on 2023/9/17.
//

import UIKit
import AVFAudio
import AVFoundation
import WebrtcLib

class FinalCallViewController: UIViewController {
        //MARK - audio variables
        let audioProcessQueue = DispatchQueue(label: "audio process queue")
        var audioEngine = AVAudioEngine()
        var audioPlayer:AVAudioPlayerNode!
        var isSpeaker:Bool!
        var audioRecover:AudioRecover!
        var hasVideoChannel:Bool = false
        
        var muteLocal:Bool = false
        var muteRemote:Bool = false
        
        //MARK - video variable
        var selfLayer = AVSampleBufferDisplayLayer()
        var peerLayer = AVSampleBufferDisplayLayer()
        lazy var captureManager = VideoCaptureManager()
        lazy var videoEncoder = H264Encoder()
        let naluParser = NALUParser()
        
        // MARK: - ui logic
        override func viewDidLoad() {
                super.viewDidLoad()
                self.hideKeyboardWhenTappedAround()
                
#if USE_LOCAL_LOGIC
                do{
                        try initAudioEngine()
                        initVidoeEngine()
                        
                }catch let err{
                        print("------>>> init system err:", err.localizedDescription)
                }
#endif
                
        }
        
        override func viewWillAppear(_ animated: Bool) {
                super.viewWillAppear(animated)
                
                // MARK: 1 - Asks user for microphone permission
                
                if AVCaptureDevice.authorizationStatus(for: AVMediaType.audio) != .authorized {
                        AVCaptureDevice.requestAccess(for: AVMediaType.audio,
                                                      completionHandler: { (granted: Bool) in
                                if !granted{
                                        print("------>>>audio operation not granted ")
                                }
                        })
                }
        }
        
        
        @IBAction func startAudioCall(_ sender: UIButton) {
                startAudioCall(isCaller: true)
        }
        
        @IBAction func answerAudioCall(_ sender: UIButton) {
                startAudioCall(isCaller: false)
        }
        
        private func startAudioCall(isCaller:Bool){
#if USE_LOCAL_LOGIC
                self.hasVideoChannel = false
                var err:NSError?
                WebrtcLibStartCall(self.hasVideoChannel, isCaller, "alice-to-bob", self, &err)
                if let e = err{
                        print("------>>> start audio call failed \(e.localizedDescription)")
                        return
                }
#else
                guard  let vc = storyboard?.instantiateViewController(withIdentifier: "UIAudioViewController") as? UIAudioViewController else{
                        return
                }
                vc.modalPresentationStyle = .fullScreen
                vc.isCaller = isCaller
                self.present(vc, animated: true)
#endif
        }
        
        @IBAction func startVideoCall(_ sender: UIButton) {
                self.startVideoCall(isCaller: true)
        }
        
        @IBAction func answerVideoCall(_ sender: UIButton) {
                self.startVideoCall(isCaller: false)
                
        }
        
        private func startVideoCall(isCaller:Bool){
#if USE_LOCAL_LOGIC
                self.hasVideoChannel = true
                view.layer.addSublayer(frontTopLayer)
                view.layer.addSublayer(backgroundLayer)
                var err:NSError?
                WebrtcLibStartCall(self.hasVideoChannel, isCaller, "alice-to-bob", self, &err)
                if let e = err{
                        print("------>>> start audio call failed \(e.localizedDescription)")
                        return
                }
                try! videoEncoder.configureCompressSession()
                captureManager.startSession()
#else
                guard  let vc = storyboard?.instantiateViewController(withIdentifier: "UIVideoViewController") as? UIVideoViewController else{
                        return
                }
                vc.modalPresentationStyle = .fullScreen
                vc.isCaller = isCaller
                self.present(vc, animated: true)
#endif
        }
        
        @IBAction func switchSpeaker(_ sender: UIButton) {
                self.switchSpeaker()
        }
        
        @IBAction func muteLocal(_ sender: UIButton) {
                muteLocal = !muteLocal
        }
        
        @IBAction func mutePeer(_ sender: UIButton) {
                muteRemote = !muteRemote
        }
        //        override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        //                if segue.identifier == "ShowUIAudioViewControllerSEG"{
        //                        guard let vc = segue.destination as? UIAudioViewController else{
        //                                return
        //                        }
        //                        vc.isCaller = true
        //                }else if segue.identifier == "ShowUIAudioViewControllerSEG"{
        //                        guard let vc = segue.destination as? UIAudioViewController else{
        //                                return
        //                        }
        //                        vc.isCaller = false
        //                }
        //        }
}

//MARK: - business logic
extension FinalCallViewController{
        func endingCall(){
                audioPlayer.stop()
                audioEngine.stop()
                
                self.peerLayer.removeFromSuperlayer()
                self.selfLayer.removeFromSuperlayer()
                
                captureManager.stop()
        }
}
