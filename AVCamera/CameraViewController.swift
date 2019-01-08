//
//  CameraViewController.swift
//  AVCamera
//
//  Created by Hồng Chinh on 12/29/18.
//  Copyright © 2018 Hồng Chinh. All rights reserved.
//

import UIKit
import AVFoundation
import Photos

class CameraViewController: UIViewController,AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        <#code#>
    }
    

    @IBOutlet weak var previewView: PreviewView!
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        // Set up the video preview view.
        previewView.session = session
        /*
         Check video authorization status. Video access is required and audio
         access is optional. If the user denies audio access, AVCam won't
         record audio during movie recording.
         */
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            // The user has previously granted access to the camera.
            break
        case .notDetermined:
            /*
             The user has not yet been presented with the option to grant
             video access. We suspend the session queue to delay session
             setup until the access request has completed.
             
             Note that audio access will be implicitly requested when we
             create an AVCaptureDeviceInput for audio during session setup.
             */
            //Đình chỉ việc gọi các đối tượng
            sessionQueue.suspend()
            AVCaptureDevice.requestAccess(for: .video, completionHandler: { granted in if !granted {
                self.setupResult = .notAuthorized
                }
                self.sessionQueue.resume()
            })
            
        default:
            // The user has previously denied access.
            setupResult = .notAuthorized
            /*
             Setup the capture session.
             In general, it is not safe to mutate an AVCaptureSession or any of its
             inputs, outputs, or connections from multiple threads at the same time.
             
             Don't perform these tasks on the main queue because
             AVCaptureSession.startRunning() is a blocking call, which can
             take a long time. We dispatch session setup to the sessionQueue, so
             that the main queue isn't blocked, which keeps the UI responsive.
             */
            sessionQueue.async {
                self.configureSession()
            }
        }
        

    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    
    
    //Định hướng giao diện được hỗ trợ
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask{
        return .all
    }
    
    
    
    // MARK: Session Management
    private enum SessionSetupResult {
        case success
        case notAuthorized
        case configurationFailed
    }
    
    private let session = AVCaptureSession()
    
    private var isSessionRunning = false
    
    // Communicate with the session and other session objects on this queue.
    private let sessionQueue = DispatchQueue(label: "session queue")
    
    private var setupResult: SessionSetupResult = .success
    @objc dynamic var videoDeviceInput: AVCaptureDeviceInput!
    
    // Call this on the session queue.
    /// - Tag: ConfigureSession
    private func configureSession() {
        if setupResult != .success {
            return
        }
        
        //bat dau cau hinh
        session.beginConfiguration()
        
        /*
         We do not create an AVCaptureMovieFileOutput when setting up the session because
         Live Photo is not supported when AVCaptureMovieFileOutput is added to the session.
         */
        session.sessionPreset = .photo
        
        // Add video input.
        do {
            var defaultVideoDevice: AVCaptureDevice?
            //thiết bị camera kép
            if let dualCameraDevice = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back) {
                defaultVideoDevice = dualCameraDevice
            } else if let backCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
                // Nếu không có camera kép phía sau, mặc định cho camera góc rộng phía sau.
                defaultVideoDevice = backCameraDevice
            } else if let frontCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) {
                //Trong trường hợp camera góc rộng phía sau không khả dụng, mặc định là camera góc rộng phía trước.
                defaultVideoDevice = frontCameraDevice
            }
            guard let videoDevice = defaultVideoDevice else {
                print("Default video device is unavailable.")
                setupResult = .configurationFailed
                session.commitConfiguration()
                return
            }
            let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
            
            if session.canAddInput(videoDeviceInput) {
                session.addInput(videoDeviceInput)
                self.videoDeviceInput = videoDeviceInput
                    
                    DispatchQueue.main.async {
                        let statusBarOrientation = UIApplication.shared.statusBarOrientation
                        var initialVideoOrientation: AVCaptureVideoOrientation = .portrait
                        if statusBarOrientation != .unknown {
                            if let videoOrientation = AVCaptureVideoOrientation(interfaceOrientation: statusBarOrientation) {
                                initialVideoOrientation = videoOrientation
                            }
                        }
                        
                        self.previewView.videoPreviewLayer.connection.v
                        
                        
                        
                        
                    }
                
            }
        
            
            
            
            
            
        }
    }
    
    // MARK: Device Configuration
    
    @IBOutlet weak var changeCamera: UIButton!
    
    @IBOutlet weak var cameraUnavailableLabel: UILabel!
    
    @IBAction func changeCamera(_ sender: Any) {
    }
    
    
    
    
    

}
