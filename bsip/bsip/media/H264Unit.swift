//
//  H264Unit.swift
//  bsip
//
//  Created by wesley on 2023/8/18.
//

import Foundation

struct H264Unit {
        
        enum NALUType {
                case unknown
                case sps
                case pps
                case iFrame
                case pFrame
                case vcl
        }
        
        let type: NALUType
        var payload: Data
        
        init(type:NALUType, payload: Data) {
                self.type = type
                self.payload = payload
        }
}

