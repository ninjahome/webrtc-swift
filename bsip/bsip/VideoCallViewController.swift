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
        
        private let selfLayer = AVSampleBufferDisplayLayer()
        private let peerLayer = AVSampleBufferDisplayLayer()
        private lazy var captureManager = VideoCaptureManager()
        private lazy var videoEncoder = H264Encoder()
        private let naluParser = NALUParser()
        
        @IBOutlet var remoteSDP: UITextView!
        
        override func viewDidLoad() {
                super.viewDidLoad()
                self.hideKeyboardWhenTappedAround()
                peerLayer.frame = view.frame
                peerLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
                
                selfLayer.frame = CGRect(origin: CGPoint(x: 0,y: 0), size: CGSize(width: 72, height: 120))
                
                captureManager.setVideoOutputDelegate(with: self)
                videoEncoder.naluHandling = self.compressedData
                naluParser.sampleBufferCallback = self.presentResult
                
                NotificationCenter.default.addObserver(self,
                                                       selector:#selector(checkCallSession(notification:)),
                                                       name: NotifyAppBecomeActive,
                                                       object: nil)
        }
        
        @objc func checkCallSession(notification: NSNotification) {
                print("------>>>isrunning:=>",captureManager.running())
                if captureManager.running(){
                        try? videoEncoder.configureCompressSession()
                }
        }

        
        @IBAction func setupCalleeAnswer(_ sender: UIButton) {
                guard let offer = remoteSDP.text else{
                        print("------>>> callee answer is empty")
                        return
                }
                WebrtcLibSetAnswerForOffer(offer)
        }
        
        
        @IBAction func startVideoAction(_ sender: UIButton) {
                
                peerLayer.addSublayer(selfLayer)
                view.layer.addSublayer(peerLayer)
                
                do{
                        var err:NSError?
                        WebrtcLibStartVideo(self, &err)
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
                
                peerLayer.addSublayer(selfLayer)
                view.layer.addSublayer(peerLayer)
                
                
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
                
                videoEncoder.encode(buffer: sampleBuffer)
        }
}

extension VideoCallViewController:WebrtcLibCallBackProtocol{
        
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
                
                naluParser.enqueue(typ, data)
        }
}

