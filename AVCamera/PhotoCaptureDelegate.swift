//
//  ViewController.swift
//  AVCamera
//
//  Created by Hồng Chinh on 12/29/18.
//  Copyright © 2018 Hồng Chinh. All rights reserved.
//

import AVFoundation
import Photos

class PhotoCaptureProcessor: NSObject {
    private(set) var requestedPhotoSettings: AVCapturePhotoSettings
    
    private let willCapturePhotoAnimation: () -> Void
    
    private let livePhotoCaptureHandler: (Bool) -> Void
    
    lazy var context = CIContext()
    private let completionHandler: (PhotoCaptureProcessor) -> Void
    
    private var photoData: Data?
    
    private var livePhotoCompanionMovieURL: URL?
    
    private var portraitEffectsMatteData: Data?
    
     init(with requestedPhotoSettings: AVCapturePhotoSettings,
                  willCapturePhotoAnimation: @escaping () -> Void,
                  livePhotoCaptureHandler: @escaping (Bool) -> Void,
                  completionHandler: @escaping(PhotoCaptureProcessor) -> Void) {
        self.requestedPhotoSettings = requestedPhotoSettings
        self.willCapturePhotoAnimation = willCapturePhotoAnimation
        self.livePhotoCaptureHandler = livePhotoCaptureHandler
        self.completionHandler = completionHandler
    }

    private func didFinsh() {
        if let livePhotoCompanionMoviePath = livePhotoCompanionMovieURL?.path {
            if FileManager.default.fileExists(atPath: livePhotoCompanionMoviePath)
            {
               do {
                try FileManager.default.removeItem(atPath: livePhotoCompanionMoviePath)
               } catch {
                print("Could not remove file at url: \(livePhotoCompanionMoviePath)")
                }
            }
        }
        completionHandler(self)
    }
}

