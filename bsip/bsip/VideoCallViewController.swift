//
//  VideoCallViewController.swift
//  bsip
//
//  Created by wesley on 2023/8/18.
//

import UIKit
import WebrtcLib
import AVFoundation

class VideoCallViewController: UIViewController {
        
        private var selfLayer = AVSampleBufferDisplayLayer()
        private var peerLayer = AVSampleBufferDisplayLayer()
        private lazy var captureManager = VideoCaptureManager()
        private lazy var videoEncoder = H264Encoder()
        private let naluParser = NALUParser()
        
        @IBOutlet var remoteSDP: UITextView!
        
        override func viewDidLoad() {
                super.viewDidLoad()
                self.hideKeyboardWhenTappedAround()
                
                
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
                setupLayer()
        }
        
        private func setupLayer(){
                selfLayer = AVSampleBufferDisplayLayer()
                peerLayer = AVSampleBufferDisplayLayer()
                peerLayer.frame = view.frame
                peerLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
                selfLayer.frame = CGRect(origin: CGPoint(x: 0,y: 0), size: CGSize(width: 72, height: 120))
        }
        
        @objc func checkCallSession(notification: NSNotification) {
                print("------>>>isrunning:=>",captureManager.running(), captureManager.isInter())
                setupLayer()
                if captureManager.running()||captureManager.isInter(){
                        try? videoEncoder.configureCompressSession()
                        view.layer.addSublayer(peerLayer)
                        view.layer.addSublayer(selfLayer)
                }
        }
        
        @objc func removLayers(notification: NSNotification) {
                self.peerLayer.removeFromSuperlayer()
                self.selfLayer.removeFromSuperlayer()
        }

        
        @IBAction func setupCalleeAnswer(_ sender: UIButton) {
                guard let offer = remoteSDP.text else{
                        print("------>>> callee answer is empty")
                        return
                }
                WebrtcLibSetAnswerForOffer(offer)
        }
        
        
        @IBAction func startCalledVideoAction(_ sender: UIButton) {
                startVideo(isCaller: false)
        }
        
        @IBAction func startVideoAction(_ sender: UIButton) {
                startVideo(isCaller: true)
        }
        
        private func startVideo(isCaller:Bool = true){
                
                view.layer.addSublayer(peerLayer)
                view.layer.addSublayer(selfLayer)
                
                do{
                        var err:NSError?
                        WebrtcLibStartVideo(isCaller,self, &err)
                        if let e = err{
                                throw e
                        }
                        try videoEncoder.configureCompressSession()
                        captureManager.startSession()
                        
                }catch let e{
                        print("------>>>startVideoAction:",e.localizedDescription)
                }
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
        
        @IBAction func answerVideoAction(_ sender: Any) {
                guard let offer = remoteSDP.text else{
                        print("------>>> setup answer is empty")
                        return
                }
                
                view.layer.addSublayer(peerLayer)
                view.layer.addSublayer(selfLayer)
                
                
                do {
                        var err:NSError?
                        WebrtcLibAnswerVideo(offer,self,&err)
                        if let e = err{
                                throw e
                        }
                        
                        try videoEncoder.configureCompressSession()
                        captureManager.startSession()
                        
                        
                }catch let err{
                        print("------>>>answerVideoAction:",err.localizedDescription)
                }
                
        }
        
        @IBAction func TestFileAction(_ sender: UIButton) {
                view.layer.addSublayer(peerLayer)
                
                let filePath = Bundle.main.path(forResource: "offer", ofType: "h264")
                let url = URL(fileURLWithPath: filePath!)
                let videoReader = VideoFileReader()
                videoReader.callback = self
                videoReader.filequeue.async {
                        videoReader.openVideoFile(url)
                }
                naluParser.sampleBufferCallback = self.presentResult
        }
        
        private  func presentResult(_ sample:CMSampleBuffer){
                peerLayer.enqueue(sample)
        }
        
        /*
         // MARK: - Navigation
         
         // In a storyboard-based application, you will often want to do a little preparation before navigation
         override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
         // Get the new view controller using segue.destination.
         // Pass the selected object to the new view controller.
         }
         */
}


extension VideoCallViewController: AVCaptureVideoDataOutputSampleBufferDelegate{
        func captureOutput(_ output: AVCaptureOutput,
                           didOutput sampleBuffer: CMSampleBuffer,
                           from connection: AVCaptureConnection) {
                
                selfLayer.enqueue(sampleBuffer)
//                peerLayer.enqueue(sampleBuffer)
                videoEncoder.encode(buffer: sampleBuffer)
        }
}

extension VideoCallViewController:WebrtcLibCallBackProtocol{
        func connected() {
                
        }
        
        func disconnected() {
                
        }
        
        func newAudioData(_ data: Data?) {
                print("------>>>why audio")
        }
        
        
        func answerCreated(_ p0: String?) {
                guard let answer = p0 else{
                        WebrtcLibEndCall()
                        return
                }
                print(answer)
        }
        
        func offerCreated(_ p0: String?) {
                guard let offer = p0 else{
                        WebrtcLibEndCall()
                        return
                }
                
                print(offer)
        }
        
        
        func newVideoData(_ typ: Int, h264data: Data?) {
                
                guard let data = h264data else{
                        return
                }
                naluParser.parsingQueue.async {
                        self.naluParser.enqueue(typ, data)
                }
        }
}

