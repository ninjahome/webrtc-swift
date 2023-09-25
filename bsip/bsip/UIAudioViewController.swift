//
//  UIAudioViewController.swift
//  bsip
//
//  Created by wesley on 2023/9/24.
//

import UIKit
import AVFAudio
import WebrtcLib

class UIAudioViewController: UIViewController {
        
        @IBOutlet var speakerBtn: UIButton!
        @IBOutlet var micPhoneBtn: UIButton!
        
        var micStatusOn:Bool = true
        var sperakerOn:Bool = false
        public var isCaller:Bool = true
        
        let audioProcessQueue = DispatchQueue(label: "audio process queue")
        var audioEngine:AVAudioEngine!
        var audioPlayer:AVAudioPlayerNode!
        var ringingPlayer:AVAudioPlayer?
        var audioRecover:AudioRecover!
        
        override func viewDidLoad() {
                super.viewDidLoad()
        }
        
        override func viewDidAppear(_ animated: Bool) {
                super.viewDidAppear(animated)
                self.playCallRing()
                self.audioProcessQueue.async { [self] in
                        initAudioEngine()
                        startAudioCall(isCaller: self.isCaller)
                }
        }
        
        private func startAudioCall(isCaller:Bool){
                var err:NSError?
                WebrtcLibStartCall(false, isCaller, "alice-to-bob", self, &err)
                if let e = err{
                        print("------>>> start audio call failed \(e.localizedDescription)")
                        return
                }
        }
        
        @IBAction func EndAudioCall(_ sender: UIButton) {
                WebrtcLibEndCallByController()
                self.resetDevice()
        }
        
        @IBAction func turnOnOffSpeaker(_ sender: UIButton) {
                self.sperakerOn = !self.sperakerOn
                if self.sperakerOn{
                        speakerBtn.setImage(UIImage(named: "speaker_o"), for: .normal)
                        speakerBtn.setTitle("扬声器已开", for: .normal)
                        try! AVAudioSession.sharedInstance().overrideOutputAudioPort(.speaker)
                }else{
                        speakerBtn.setImage(UIImage(named:"speaker_c"), for: .normal)
                        speakerBtn.setTitle("扬声器已关", for: .normal)
                        try! AVAudioSession.sharedInstance().overrideOutputAudioPort(.none)
                }
                
                try! AVAudioSession.sharedInstance().setActive(true)
        }
        
        @IBAction func turnOnOffMicAct(_ sender: UIButton) {
                self.micStatusOn = !self.micStatusOn
                if self.micStatusOn{
                        micPhoneBtn.setImage(UIImage(named: "microphone_o"), for: .normal)
                        micPhoneBtn.setTitle("麦克已开", for: .normal)
                }else{
                        micPhoneBtn.setImage(UIImage(named:"microphone_c"), for: .normal)
                        micPhoneBtn.setTitle("麦克已关", for: .normal)
                }
        }
}

extension UIAudioViewController{
        
        func playCallRing(){
                let filePath: String = Bundle.main.path(forResource: "ringing", ofType: "mp3")!
                let fileUrl = URL(string: filePath)
                ringingPlayer = try? AVAudioPlayer(contentsOf: fileUrl!)
                ringingPlayer!.numberOfLoops = -1
                ringingPlayer!.volume = 1.0
                ringingPlayer!.prepareToPlay()
                ringingPlayer?.play()
        }
        
        func initAudioEngine() {
                do{
                        try AVAudioSession.sharedInstance().setCategory(.playAndRecord,
                                                                        mode: .voiceChat,
                                                                        options: [.allowBluetooth])
                        
                        try AVAudioSession.sharedInstance().overrideOutputAudioPort(.none)
                        try AVAudioSession.sharedInstance().setActive(true)
                        
                        audioEngine = AVAudioEngine()
                        let input = audioEngine.inputNode
                        try input.setVoiceProcessingEnabled(true)
                        
                        let bus = 0
                        let inputFormat = input.inputFormat(forBus: bus)
                        
                        guard  let of = AVAudioFormat(commonFormat: AVAudioCommonFormat.pcmFormatInt16,
                                                      sampleRate: 44100,
                                                      channels: 1,
                                                      interleaved: true) else{
                                throw NSError(domain: "audio output foramt err", code: -1)
                        }
                        let outputFormat = of
                        
                        guard let c = AudioRecover(fromFmt: outputFormat, toFmt: inputFormat) else{
                                throw  NSError(domain: "audio recover err", code: -1)
                        }
                        audioRecover = c
                        
                        audioPlayer = AVAudioPlayerNode()
                        audioEngine.attach(audioPlayer)
                        
                        audioEngine.connect(audioPlayer,
                                            to: audioEngine.outputNode,
                                            format: inputFormat)
                        
                        input.installTap(onBus: bus,
                                         bufferSize: 4096,
                                         format: outputFormat,
                                         block: self.audioProcess)
                        
                        audioEngine.prepare()
                }catch let e {
                        print("------>>>init audio engine failed:",e.localizedDescription)
                }
        }
        
        func audioProcess(buffer:AVAudioPCMBuffer, time:AVAudioTime) {
                if self.micStatusOn == false{
                        return
                }
                
                self.audioProcessQueue.async {
                        let data = Data(pcmBuffer:buffer, time: time)
                        var err:NSError?
                        WebrtcLibSendAudioToPeer(data, &err)
                        if let e = err{
                                print("------>>> write audio data err:", e.localizedDescription)
                        }
                }
        }
        
        func resetDevice(){
                audioPlayer.stop()
                audioEngine.stop()
                ringingPlayer?.stop()
                
                try? AVAudioSession.sharedInstance().setActive(false)
                DispatchQueue.main.async {
                        self.dismiss(animated: true)
                }
        }
}


extension UIAudioViewController:WebrtcLibCallBackProtocol{
        func answerCreated(_ p0: String?) {
                
        }
        
        func connected() {
                do{
                        try audioEngine.start()
                        audioPlayer.play()
                        ringingPlayer?.stop()
                }catch let err{
                        print("------>>> start audio engine failed:",err.localizedDescription)
                        WebrtcLibEndCallByController()
                        self.resetDevice()
                }
        }
        
        func disconnected() {
                self.resetDevice()
        }
        
        func newAudioData(_ data: Data?) {
                
                self.audioProcessQueue.async{
                        guard let d = data else{
                                print("------>>> receive empty audio data")
                                return
                        }
                        
                        guard let buffer = self.audioRecover.recover(data: d) else{
                                print("------>>> recover audio data failed")
                                return
                        }
                        self.audioPlayer.scheduleBuffer(buffer)
                }
        }
        
        func newVideoData(_ typ: Int, h264data: Data?) {
                
        }
        
        func offerCreated(_ p0: String?) {
                guard let offer = p0 else{
                        print("------>>> empty offer string")
                        self.resetDevice()
                        return
                }
                let answer = WebrtcLibSdpToRelay(RelayHostUrl, offer)
                if answer.isEmpty{
                        self.resetDevice()
                        return
                }
                WebrtcLibSetAnswerForOffer(answer)
        }
}
