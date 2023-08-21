//
//  Util.swift
//  bsip
//
//  Created by wesley on 2023/8/19.
//

import Foundation
import UIKit

extension UIViewController {
        
        @objc func dismissKeyboard() {
                view.endEditing(true)
        }
        
        func hideKeyboardWhenTappedAround() { DispatchQueue.main.async {
                let tap = UITapGestureRecognizer(target: self, action: #selector(UIViewController.dismissKeyboard))
                tap.cancelsTouchesInView = false
                self.view.addGestureRecognizer(tap)
        }}
}
public extension UnsafePointer {
    
    func copy(capacity: Int) -> UnsafePointer {
        
        let mutablePointer = UnsafeMutablePointer<Pointee>.allocate(capacity: capacity)
        mutablePointer.initialize(from: self, count:capacity)
        return UnsafePointer(mutablePointer)
        
    }
    
}
