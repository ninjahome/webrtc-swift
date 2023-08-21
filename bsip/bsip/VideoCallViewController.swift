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
        private let h264Converter = H264Converter()
//        private var h264Decoder: VideoDecoder!
        
        @IBOutlet var remoteSDP: UITextView!
        
//        private var cacher:NALUParser2!
        
        override func viewDidLoad() {
                super.viewDidLoad()
                self.hideKeyboardWhenTappedAround()
                peerLayer.frame = view.frame
                peerLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
                
                selfLayer.frame = CGRect(origin: CGPoint(x: 0,y: 0), size: CGSize(width: 72, height: 120))
                
//                h264Decoder = H264Decoder(delegate: self)
//                cacher = NALUParser2(decoder:h264Decoder)
        }
        
        @IBAction func startVedioAction(_ sender: UIButton) {
                peerLayer.addSublayer(selfLayer)
                view.layer.addSublayer(peerLayer)
                captureManager.setVideoOutputDelegate(with: videoEncoder)
                showVideo()
        }
        
        private func showVideo(){
                guard let offer = remoteSDP.text else{
                        return
                }
                
                do {
                        var err:NSError?
                        WebrtcLibStartVideo(offer,self,&err)
                        if let e = err{
                                print("------>>>",e.localizedDescription)
                                return
                        }
                        
                        try videoEncoder.configureCompressSession()
                        
                        captureManager.setVideoOutputDelegate(with: self)
                        
                        videoEncoder.naluHandling = { data in
//                                self.naluParser.enqueue(data)
                                WebrtcLibSendVideoToPeer(data, &err)
                                if let e = err{
                                        print("------>>>",e.localizedDescription)
                                }
                        }
                        
                        
                        naluParser.h264UnitHandling = { [h264Converter] h264Unit in
                                h264Converter.convert(h264Unit)
                        }

                        h264Converter.sampleBufferCallback = self.presentResult
                        
                }catch let err{
                        print("------>>>",err.localizedDescription)
                }
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
        
        func newVideoData(_ h264data: Data?) {
                guard let data = h264data else{
                        return
                }
                
                naluParser.enqueue(data)
        }
}

