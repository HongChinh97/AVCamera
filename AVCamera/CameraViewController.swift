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

class CameraViewController: UIViewController {
    
    private let session = AVCaptureSession()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        // Set up the video preview view.
        previewView.session = session
        /*
         
         Kiểm tra trạng thái ủy quyền video. Yêu cầu truy cập video và âm thanh
         truy cập là tùy chọn. Nếu người dùng từ chối truy cập âm thanh, AVCam sẽ không ghi lại âm thanh trong khi quay phim.
         */
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            // Người dùng trước đây đã cấp quyền truy cập vào máy ảnh.
            break
        case .notDetermined:
            /*
             
             Người dùng chưa được cung cấp tùy chọn cấp
             truy cập video. Chúng tôi tạm dừng hàng đợi phiên để trì hoãn phiên
             thiết lập cho đến khi yêu cầu truy cập đã hoàn thành.
             
             Lưu ý rằng quyền truy cập âm thanh sẽ được yêu cầu ngầm khi chúng tôi
             tạo AVCaptureDeviceInput cho âm thanh trong khi thiết lập phiên.
             */
            //Đình chỉ việc gọi các đối tượng
            sessionQueue.suspend()
            AVCaptureDevice.requestAccess(for: .video, completionHandler: { granted in if !granted {
                self.setupResult = .notAuthorized
                }
                self.sessionQueue.resume()
            })
            
        default:
            // Người dùng trước đây đã từ chối truy cập.
            setupResult = .notAuthorized
        }
        /*
         
         
         Thiết lập phiên chụp.
         Nói chung, không an toàn khi đột biến AVCaptureSession hoặc bất kỳ
         đầu vào, đầu ra hoặc kết nối từ nhiều luồng cùng một lúc.
         
         Đừng thực hiện các tác vụ này trên hàng đợi chính vì
         AVCaptureSession.startRasty () là một cuộc gọi chặn, có thể
         mất nhiều thời gian. Chúng tôi gửi thiết lập phiên tới sessionQueue, vì vậy rằng hàng đợi chính không bị chặn, giúp giao diện người dùng phản ứng nhanh.
         */
        sessionQueue.async {
            self.configureSession()
        }
        
        
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        sessionQueue.async {
            switch self.setupResult {
            case .success:
                // Only setup observers and start the session running if setup succeeded.
                //                self.addObservers()
                self.session.startRunning()
                self.isSessionRunning = self.session.isRunning
                
            case .notAuthorized:
                DispatchQueue.main.async {
                    let changePrivacySetting = "AVCam doesn't have permission to use the camera, please change privacy settings"
                    let message = NSLocalizedString(changePrivacySetting, comment: "Alert message when the user has denied access to the camera")
                    let alertController = UIAlertController(title: "AVCam", message: message, preferredStyle: .alert)
                    
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"),
                                                            style: .cancel,
                                                            handler: nil))
                    
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("Settings", comment: "Alert button to open Settings"),
                                                            style: .`default`,
                                                            handler: { _ in
                                                                UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!,
                                                                                          options: [:],
                                                                                          completionHandler: nil)
                    }))
                    
                    self.present(alertController, animated: true, completion: nil)
                }
                
            case .configurationFailed:
                DispatchQueue.main.async {
                    let alertMsg = "Alert message when something goes wrong during capture session configuration"
                    let message = NSLocalizedString("Unable to capture media", comment: alertMsg)
                    let alertController = UIAlertController(title: "AVCam", message: message, preferredStyle: .alert)
                    
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"),
                                                            style: .cancel,
                                                            handler: nil))
                    
                    self.present(alertController, animated: true, completion: nil)
                }
            }
        }
    }
    
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        if let videoPreviewLayerConnection = previewView.videoPreviewLayer.connection {
            let deviceOrientation = UIDevice.current.orientation
            guard let newVideoOrientation = AVCaptureVideoOrientation(rawValue: deviceOrientation.rawValue),
                deviceOrientation.isPortrait || deviceOrientation.isLandscape else {
                    return
            }
            
            videoPreviewLayerConnection.videoOrientation = newVideoOrientation
        }
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
    
    
    private var isSessionRunning = false
    
    //Giao tiếp với phiên và các đối tượng phiên khác trên hàng đợi này.
    private let sessionQueue = DispatchQueue(label: "session queue")
    
    private var setupResult: SessionSetupResult = .success
    
    @objc dynamic var videoDeviceInput: AVCaptureDeviceInput!
    
    @IBOutlet weak var previewView: PreviewView!
    
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
         Live Photo không được hỗ trợ khi AVCaptureMovieFileOutput được thêm vào
         phiên.
         */
        session.sessionPreset = .photo
        
        // Add video input.
        addVideoInput()
        
        //add audio input
        addAudioInput()
        
        //add audio output
        addPhotoOutput()
        session.commitConfiguration()
        
    }
    
    func addVideoInput() {
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
    }
    
    func addAudioInput() {
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
    }
    
    func addPhotoOutput() {
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            
            photoOutput.isHighResolutionCaptureEnabled = true
            photoOutput.isPortraitEffectsMatteDeliveryEnabled = photoOutput.isPortraitEffectsMatteDeliverySupported
        } else {
            print("Could not add photo output to the session")
            setupResult = .configurationFailed
            session.commitConfiguration()
            return
        }
    }
    
   
    
    private enum CaptureMode: Int {
        case photo = 0
        case movie = 1
    }
    
    @IBOutlet weak var captureModeControl: UISegmentedControl!
    
  
    
    // MARK: Capturing Photos
    private let photoOutput = AVCapturePhotoOutput()
    
    ///Tag: ChangeCamera
    
    private let videoDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .builtInDualCamera, .builtInTrueDepthCamera],
                                                                               mediaType: .video, position: .unspecified)
    private var movieFileOutput: AVCaptureMovieFileOutput?

    @IBAction func changeCamera(_ sender: UIButton) {
        sessionQueue.async {
            let currentVideoDevice = self.videoDeviceInput.device
            let currentPosition = currentVideoDevice.position
            
            let preferredPosition: AVCaptureDevice.Position
            let preferredDeviceType: AVCaptureDevice.DeviceType
            
            switch currentPosition {
            case .unspecified, .front:
                preferredPosition = .back
                preferredDeviceType = .builtInDualCamera
                
            case .back:
                preferredPosition = .front
                preferredDeviceType = .builtInTrueDepthCamera
            }
            
            let devices = self.videoDeviceDiscoverySession.devices
            var newVideoDevice: AVCaptureDevice? = nil
            if let device = devices.first(where: { $0.position == preferredPosition && $0.deviceType == preferredDeviceType}) {
                newVideoDevice = device
            } else if let device = devices.first(where: { $0.position == preferredPosition}) {
                newVideoDevice = device
            }
            
            if let videoDevice = newVideoDevice {
                do {
                    let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
                    self.session.beginConfiguration()
                    self.session.removeInput(self.videoDeviceInput)
                    if self.session.canAddInput(videoDeviceInput) {
                        NotificationCenter.default.removeObserver(self, name: .AVCaptureDeviceSubjectAreaDidChange, object: currentVideoDevice)
                        NotificationCenter.default.addObserver(self, selector: #selector(self.subjectAreaDidChange), name: .AVCaptureDeviceSubjectAreaDidChange, object: videoDeviceInput.device)
                        
                        self.session.addInput(videoDeviceInput)
                        self.videoDeviceInput = videoDeviceInput
                    }else {
                        self.session.addInput(self.videoDeviceInput)
                    }
                    if let connection = self.movieFileOutput?.connection(with: .video) {
                        if connection.isVideoStabilizationSupported {
                            connection.preferredVideoStabilizationMode = .auto
                        }
                    }
                    self.photoOutput.isLivePhotoCaptureEnabled = self.photoOutput.isLivePhotoCaptureSupported
                    self.photoOutput.isDepthDataDeliveryEnabled = self.photoOutput.isDepthDataDeliverySupported
                    self.photoOutput.isPortraitEffectsMatteDeliveryEnabled = self.photoOutput.isPortraitEffectsMatteDeliverySupported
                    
                    self.session.commitConfiguration()
                } catch {
                    print("Error occurred while creating video device input \(error)")
                }
                
               
            }
            
        }
    }
    
    @objc
    func subjectAreaDidChange(notification: NSNotification) {
        let devicePoint = CGPoint(x: 0.5, y: 0.5)
        focus(with: .continuousAutoFocus, exposureMode: .continuousAutoExposure, at: devicePoint, monitorSubjectAreaChange: false)
    }
    
    private func focus(with focusMode: AVCaptureDevice.FocusMode,
                       exposureMode: AVCaptureDevice.ExposureMode,
                       at devicePoint: CGPoint,
                       monitorSubjectAreaChange: Bool) {
        
        sessionQueue.async {
            let device = self.videoDeviceInput.device
            do {
                try device.lockForConfiguration()
                
                /*
                 Setting (focus/exposure)PointOfInterest alone does not initiate a (focus/exposure) operation.
                 Call set(Focus/Exposure)Mode() to apply the new point of interest.
                 */
                if device.isFocusPointOfInterestSupported && device.isFocusModeSupported(focusMode) {
                    device.focusPointOfInterest = devicePoint
                    device.focusMode = focusMode
                }
                
                if device.isExposurePointOfInterestSupported && device.isExposureModeSupported(exposureMode) {
                    device.exposurePointOfInterest = devicePoint
                    device.exposureMode = exposureMode
                }
                
                device.isSubjectAreaChangeMonitoringEnabled = monitorSubjectAreaChange
                device.unlockForConfiguration()
            } catch {
                print("Could not lock device for configuration: \(error)")
            }
        }
    }
    
}


