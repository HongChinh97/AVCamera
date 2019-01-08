//
//  PreviewView.swift
//  AVCamera
//
//  Created by Hồng Chinh on 12/29/18.
//  Copyright © 2018 Hồng Chinh. All rights reserved.
//

import UIKit
import AVFoundation

class PreviewView: UIView {

    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        guard let layer = layer as? AVCaptureVideoPreviewLayer else {
            fatalError("Expected `AVCaptureVideoPreviewLayer` type for layer. Check PreviewView.layerClass implementation.")
        }
        
        return layer
    }
    
    var session: AVCaptureSession? {
        get{
            return videoPreviewLayer.session
        } set{
            videoPreviewLayer.session = newValue
        }
    }
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
    
}
