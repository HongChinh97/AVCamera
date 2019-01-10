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
            session.addOutput(photoOutput)
            
            photoOutput.isHighResolutionCaptureEnabled = true
            photoOutput.isLivePhotoCaptureEnabled = photoOutput.isLivePhotoCaptureSupported
            photoOutput.isDepthDataDeliveryEnabled = photoOutput.isLivePhotoCaptureSupported
            photoOutput.isPortraitEffectsMatteDeliveryEnabled = photoOutput.isPortraitEffectsMatteDeliverySupported
            livePho
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
    
    //MARK: Recording Movies
    private var movieFileOutput: AVCaptureMovieFileOutput?
    private var backgroundRecordingID: UIBackgroundTaskIdentifier?
    
    @IBOutlet weak var recordButton: UIButton!
    
    @IBOutlet weak var resumeButton: UIButton!
    
    /// Tag: DidStartRecording
   
    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        //Kích hoạt nút Record để cho phép người dùng dừng ghi.
        DispatchQueue.main.async {
            self.recordButton.isEnabled = true
            self.recordButton.setImage(#imageLiteral(resourceName: "CaptureStop"), for: [])
    }
        
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        /*
         Vì chúng tôi sử dụng một đường dẫn tệp duy nhất cho mỗi bản ghi, một bản ghi mới sẽ không ghi đè lên bản ghi giữa lưu.
         */
        func cleanup() {
            let path = outputFileURL.path
            if FileManager.default.fileExists(atPath: path) {
                do {
                    try FileManager.default.removeItem(atPath: path)
                } catch {
                    print("Could not remove file at url: \(outputFileURL)")
                }
            }
            
            if let currentBackgroundRecordingID = backgroundRecordingID {
                backgroundRecordingID = UIBackgroundTaskIdentifier.invalid
                if currentBackgroundRecordingID != UIBackgroundTaskIdentifier.invalid {
                    UIApplication.shared.endBackgroundTask(currentBackgroundRecordingID)
                }
            }
            
        }
        
        var success = true
        if error != nil {
            print("Move file finishing error: \(String(describing: error))")
            success = (((error! as NSError).userInfo[AVErrorRecordingSuccessfullyFinishedKey] as AnyObject).boolValue)!
        }
        
        if success {
            //Kiểm tra trạng thái ủy quyền.
            PHPhotoLibrary.requestAuthorization {status in
                if status == .authorized {
                    //Lưu tập tin phim vào thư viện ảnh và dọn dẹp.
                    PHPhotoLibrary.shared().performChanges({
                        let options = PHAssetResourceCreationOptions()
                        options.shouldMoveFile = true
                        let creationRequest = PHAssetCreationRequest.forAsset()
                        creationRequest.addResource(with: .video, fileURL : outputFileURL, options: options)
                        
                    }, completionHandler: { success, error in
                        if !success {
                            print("AVCam couldn't save the movie to your photo library: \(String(describing: error))")
                        }
                        cleanup()
                    })
                } else {
                    cleanup()
                }
            }
        } else {
            cleanup()
        }
        
        //Kích hoạt các nút Camera và Record để cho phép người dùng chuyển đổi camera và bắt đầu ghi âm khác.
        DispatchQueue.main.async {
//            self.videoDeviceDiscoverySession.ui
            self.recordButton.isEnabled = true
            self.recordButton.setImage(#imageLiteral(resourceName: "CaptureVideo"), for: [])
            
        }
    }
    }
    
    //thiet lap trang thai on off cho button LivePhotoMode va DepthDataDeliveryMode
    private enum LivePhotoMode {
        case on
        case off
    }
    
    private enum DepthDataDeliveryMode {
        case on
        case off
    }
    
    private var livePhotoMode: LivePhotoMode = .off
    @IBOutlet private weak var livePhotoModeButton: UIButton!
    
    @IBAction private func toggleLivePhotoMode(_ livePhotoModeButton: UIButton) {
        sessionQueue.async {
            self.livePhotoMode = (self.livePhotoMode == .on) ? .off : .on
            let livePhotoMode = self.livePhotoMode
            
            DispatchQueue.main.async {
                if livePhotoMode == .on {
                    self.livePhotoModeButton.setImage(#imageLiteral(resourceName: "LivePhotoON"), for: [])
                } else {
                    self.livePhotoModeButton.setImage(#imageLiteral(resourceName: "LivePhotoOFF"), for: [])
                }
            }
        }
    }
    
    
    private var depthDataDeliveryMode: DepthDataDeliveryMode = .off

    
    
}
