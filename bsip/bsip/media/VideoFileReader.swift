//
//  VideoFileReader.swift
//  bsip
//
//  Created by wesley on 2023/8/23.
//

import Foundation
import WebrtcLib

typealias VideoPacket = Array<UInt8>

class VideoFileReader: NSObject {
        var callback:WebrtcLibCallBackProtocol?
        var filequeue = DispatchQueue(label: "file reader queue")
        
        func openVideoFile(_ fileURL: URL) {
                
                do{
                        let data = try Data.init(contentsOf: fileURL)
                        WebrtcLibTestFileData(callback!,data)
                }catch let err{
                        print("------>>>read data err:",err)
                }
                
        }
       
}
