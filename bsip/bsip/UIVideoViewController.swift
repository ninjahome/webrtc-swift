//
//  UIVideoViewController.swift
//  bsip
//
//  Created by wesley on 2023/9/24.
//

import UIKit
import AVFoundation
import WebrtcLib


class UIVideoViewController: UIViewController {
        //MARK: - audio viarables
        @IBOutlet var speakerBtn: UIButton!
        @IBOutlet var micPhoneBtn: UIButton!
        
        var micStatusOn:Bool = true
        var sperakerOn:Bool = false
        
        let audioProcessQueue = DispatchQueue(label: "audio process queue")
        var audioEngine:AVAudioEngine!
        var audioPlayer:AVAudioPlayerNode!
        var ringingPlayer:AVAudioPlayer?
        var audioRecover:AudioRecover!
        
        //MARK: - video viarables
        @IBOutlet var backGroundVideoView: SampleBufferVideoCallView!
        @IBOutlet var topFrontVideoView: SampleBufferVideoCallView!
        lazy var captureManager = VideoCaptureManager()
        lazy var videoEncoder = H264Encoder()
        let naluParser = NALUParser()
        var isCaller:Bool = false
        let videoProcessQueue = DispatchQueue(label: "video process queue")
        var backgroundLayer:AVSampleBufferDisplayLayer!
        var frontTopLayer:AVSampleBufferDisplayLayer!
        
        override func viewDidLoad() {
                super.viewDidLoad()
                
                backgroundLayer = backGroundVideoView.sampleBufferDisplayLayer
                backgroundLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
                frontTopLayer = topFrontVideoView.sampleBufferDisplayLayer
                frontTopLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
                
                let tap = UITapGestureRecognizer(target: self,
                                                 action: #selector(UIVideoViewController.switchVideoLayer))
                tap.cancelsTouchesInView = false
                topFrontVideoView.addGestureRecognizer(tap)
                
                topFrontVideoView.isHidden = true
        }
        
        override func viewDidAppear(_ animated: Bool) {
                super.viewDidAppear(animated)
                self.playCallRing()
                self.audioProcessQueue.async { [self] in
                        initAudioEngine()
                }
                self.videoProcessQueue.async { [self] in
                        do {
                                initVidoeEngine()
                                try self.startDevice()
                        }catch let e {
                                print("------>>>error:",e.localizedDescription)
                        }
                }
        }
        
        @objc func switchVideoLayer() {
                if backgroundLayer == backGroundVideoView.sampleBufferDisplayLayer{
                        backgroundLayer = topFrontVideoView.sampleBufferDisplayLayer
                        frontTopLayer = backGroundVideoView.sampleBufferDisplayLayer
                }else{
                        backgroundLayer = backGroundVideoView.sampleBufferDisplayLayer
                        frontTopLayer = topFrontVideoView.sampleBufferDisplayLayer
                }
        }
        
        @IBAction func endCall(_ sender: UIButton) {
                WebrtcLibEndCallByController()
                
                self.quitFromCall()
        }
        
        private func startDevice()throws{
                try videoEncoder.configureCompressSession()
                if let err = captureManager.startSession(){
                        throw err
                }
                
                var err:NSError?
                WebrtcLibStartCall(true, isCaller, "alice-to-bob", self, &err)
                if let e = err{
                        print("------>>> start audio call failed \(e.localizedDescription)")
                        throw e
                }
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

extension UIVideoViewController{
        
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
        
        func initVidoeEngine(){
                captureManager.setVideoOutputDelegate(with: self)
                videoEncoder.naluHandling = self.compressedData
                naluParser.sampleBufferCallback = self.presentResult
                
                
                NotificationCenter.default.addObserver(self,
                                                       selector:#selector(checkCallSession(notification:)),
                                                       name: NotifySceneBecomeActive,
                                                       object: nil)
                
                NotificationCenter.default.addObserver(self,
                                                       selector:#selector(removLayers(notification:)),
                                                       name: NotifySceneDidEnterBackground,
                                                       object: nil)
        }
        
        @objc func checkCallSession(notification: NSNotification) {
                print("------>>>isrunning:=>",captureManager.running(), captureManager.isInter())
                if captureManager.running()||captureManager.isInter(){
                        try? videoEncoder.configureCompressSession()
                }
        }
        
        @objc func removLayers(notification: NSNotification) {
                //TODO::
        }
        
        private func compressedData(data:Data){
                self.videoEncoder.encoderQueue.async {//TODO::change this queue to lib queue
                        var err:NSError?
                        WebrtcLibSendVideoToPeer(data, &err)
                        if let e = err{
                                print("------>>>send video err:",e.localizedDescription)
                        }
                }
        }
        
        private  func presentResult(_ sample:CMSampleBuffer){
                frontTopLayer.enqueue(sample)
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
        
        func quitFromCall(){
                DispatchQueue.main.async {
                        
                        self.dismiss(animated: true){ [self] in
                                audioPlayer.stop()
                                audioEngine.stop()
                                ringingPlayer?.stop()
                                
                                try? AVAudioSession.sharedInstance().setActive(false)
                                captureManager.stop()
                        }
                }
        }
}

extension UIVideoViewController:AVCaptureVideoDataOutputSampleBufferDelegate{
        
        func captureOutput(_ output: AVCaptureOutput,
                           didOutput sampleBuffer: CMSampleBuffer,
                           from connection: AVCaptureConnection) {
                
                backgroundLayer.enqueue(sampleBuffer)
                videoEncoder.encode(buffer: sampleBuffer)
        }
}

extension UIVideoViewController:WebrtcLibCallBackProtocol{
        
        func answerCreated(_ p0: String?) {
        }
        
        func connected() {
                DispatchQueue.main.async {
                        self.topFrontVideoView.isHidden = false
                        self.switchVideoLayer()
                }
                do{
                        try audioEngine.start()
                        audioPlayer.play()
                        ringingPlayer?.stop()
                }catch let err{
                        print("------>>> start audio engine failed:",err.localizedDescription)
                        WebrtcLibEndCallByController()
                        self.quitFromCall()
                }
        }
        
        func disconnected() {
                self.quitFromCall()
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
                guard let data = h264data else{
                        return
                }
                naluParser.parsingQueue.async {
                        self.naluParser.enqueue(typ, data)
                }
        }
        
        func offerCreated(_ p0: String?) {
                guard let offer = p0 else{
                        print("------>>> empty offer string")
                        self.quitFromCall()
                        return
                }
                let answer = WebrtcLibSdpToRelay(RelayHostUrl, offer)
                if answer.isEmpty{
                        self.quitFromCall()
                        return
                }
                WebrtcLibSetAnswerForOffer(answer)
        }
}


class SampleBufferVideoCallView: UIView {
        override class var layerClass: AnyClass {
                AVSampleBufferDisplayLayer.self
        }
        
        var sampleBufferDisplayLayer: AVSampleBufferDisplayLayer {
                layer as! AVSampleBufferDisplayLayer
        }
}
