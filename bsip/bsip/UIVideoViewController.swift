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
               
                DispatchQueue.main.async {
                        self.dismiss(animated: true){
                                WebrtcLibEndCallByController()
                                self.resetDevice()
                        }
                }
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
}

extension UIVideoViewController{
        
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
        
        func resetDevice(){
                captureManager.stop()
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
        }
        
        func disconnected() {
                DispatchQueue.main.async {
                        self.dismiss(animated: true){
                                self.resetDevice()
                        }
                }
        }
        
        func newAudioData(_ data: Data?) {
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


class SampleBufferVideoCallView: UIView {
        override class var layerClass: AnyClass {
                AVSampleBufferDisplayLayer.self
        }
        
        var sampleBufferDisplayLayer: AVSampleBufferDisplayLayer {
                layer as! AVSampleBufferDisplayLayer
        }
}
