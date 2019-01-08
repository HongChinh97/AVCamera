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
    
    
    //begin
    // MARK: Session Management
    private enum SessionSetupResult {
        case success
        case notAuthorized
        case configurationFailed
    }
    
    private let session = AVCaptureSession()
    
    private var isSessionRunning = false
    
    //Giao tiếp với phiên và các đối tượng phiên khác trên hàng đợi này.
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
         
         Chúng tôi không tạo AVCaptureMovieFileOutput khi thiết lập phiên vì
         Live Photo không được hỗ trợ khi AVCaptureMovieFileOutput được thêm vào phiên.
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
                        /*
                        Gửi luồng video đến hàng đợi chính vì AVCaptureVideoPreviewLayer là lớp hỗ trợ cho PreviewView.
                        Bạn chỉ có thể thao tác UIView trên luồng chính.
                        Lưu ý: Ngoại trừ quy tắc trên, không cần thiết phải tuần tự hóa các thay đổi hướng video
                        trên kết nối AVCaptureVideoPreviewLayer bằng các thao tác phiên khác.
                        
                        Sử dụng hướng thanh trạng thái làm hướng video ban đầu. Thay đổi định hướng tiếp theo là
                        được xử lý bởi CameraViewControll.viewWillTransition (đến: với :).
                            */
                        let statusBarOrientation = UIApplication.shared.statusBarOrientation
                        var initialVideoOrientation: AVCaptureVideoOrientation = .portrait
                        if statusBarOrientation != .unknown {
                            if let videoOrientation = AVCaptureVideoOrientation(rawValue: statusBarOrientation.rawValue) {
                                initialVideoOrientation = videoOrientation
                            }
                        }
                self.previewView.videoPreviewLayer.connection?.videoOrientation = initialVideoOrientation
                        
                    }
            } else {
                print("Couldn't add device input to the session")
                setupResult = .configurationFailed
                session.commitConfiguration()
                return
            }
        
        }catch {
            print("Couldn't create video device input: \(error)")
            setupResult = .configurationFailed
            session.commitConfiguration()
            return
        }
        
        //add audio input
        do {
            let audioDevice = AVCaptureDevice.default(for: .audio)
            let audioDeviceInput = try AVCaptureDeviceInput(device: audioDevice!)
            if session.canAddInput(audioDeviceInput) {
                session.canAddInput(audioDeviceInput)
            } else {
                print("Could not add audio device input to the session")
            }
        } catch {
            print("Could not create audio device input: \(error)")
        }
        
        //add audio output
        if session.canAddOutput(photoOutput) {
            
        }
       
        
    }

    // MARK: Device Configuration(cau hinh thiet bi)
    
    @IBOutlet weak var changeCamera: UIButton!
    
    @IBOutlet weak var cameraUnavailableLabel: UILabel!
    
    private let videoDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .builtInDualCamera, .builtInTrueDepthCamera], mediaType: .video, position: .unspecified)
    
    @IBAction func changeCamera(_ sender: Any) {
    }
    
    // MARK: Capturing Photos
    private let photoOutput = AVCapturePhotoOutput()
    private var inProgressPhotoCaptureDelegate = [Int64: PhotoCaptureProcessor]()
    
    //Kiểm soát phân đoạn giao diện người dùng
    @IBOutlet private weak var captureModeControl: UISearchController?
    

}
