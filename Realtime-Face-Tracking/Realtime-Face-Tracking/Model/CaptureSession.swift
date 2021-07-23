//
//  CaptureSession.swift
//  Realtime-Face-Tracking
//
//  Created by satoutakeshi on 2021/05/31.
//

import Foundation
import AVKit
import Combine
import SwiftUI

final class CaptureSession: NSObject, ObservableObject {

    struct Outputs {
        let cameraIntrinsicData: CFTypeRef
        let pixelBuffer: CVImageBuffer
        let pixelBufferSize: CGSize
    }
    private let captureSession = AVCaptureSession()
    private var captureDevice: AVCaptureDevice?

    private var videoDataOutput: AVCaptureVideoDataOutput?
    private var videoDataOutputQueue: DispatchQueue?
    private(set) var previewLayer = AVCaptureVideoPreviewLayer()

    var outputs = PassthroughSubject<Outputs, Never>()
    private var cancellable: AnyCancellable?
    override init() {
        super.init()
        setupCaptureSession()
    }

    /// MARK: - Create capture session
    private func setupCaptureSession() {

        captureSession.sessionPreset = .photo

        // use front camera
        if let availableDevice = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera],
                                                                  mediaType: .video,
                                                                  position: .front).devices.first {
            captureDevice = availableDevice
            do {
                let captureDeviceInput = try AVCaptureDeviceInput(device: availableDevice)
                captureSession.addInput(captureDeviceInput)
            } catch {
                print(error.localizedDescription)
            }
        }

        makePreviewLayser(session: captureSession)

        // ここだけcombine。TODO: fix later
        cancellable = NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)
            .map { _ in () }
            .prepend(()) // initial run
            .sink { [previewLayer] in
                let interfaceOrientation = UIApplication.shared.windows.first?.windowScene?.interfaceOrientation
                if let interfaceOrientation = interfaceOrientation,
                   let orientation = AVCaptureVideoOrientation(interfaceOrientation: interfaceOrientation)
                {
                    previewLayer.connection?.videoOrientation = orientation
                }
            }

        makeDataOutput()
    }

    func startSettion() {
        if captureSession.isRunning { return }
        captureSession.startRunning()
    }

    func stopSettion() {
        if !captureSession.isRunning { return }
        captureSession.stopRunning()
    }

    private func makePreviewLayser(session: AVCaptureSession) {
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.name = "CameraPreview"
        previewLayer.videoGravity = .resizeAspectFill

        previewLayer.backgroundColor = UIColor.green.cgColor
        previewLayer.borderWidth = 2
        previewLayer.borderColor = UIColor.green.cgColor
        //previewLayer.masksToBounds = true
        self.previewLayer = previewLayer
    }

    private func makeDataOutput() {
        let videoDataOutput = AVCaptureVideoDataOutput()

        videoDataOutput.videoSettings = [
            (kCVPixelBufferPixelFormatTypeKey as String): kCVPixelFormatType_32BGRA,
        ]
        // frame落ちたら捨てる処理
        videoDataOutput.alwaysDiscardsLateVideoFrames = true

        // Create a serial dispatch queue used for the sample buffer delegate as well as when a still image is captured.
        // A serial dispatch queue must be used to guarantee that video frames will be delivered in order.
        let videoDataOutputQueue = DispatchQueue(label: "com.Personal-Factory.Realtime-Face-Tracking")
        videoDataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)

        captureSession.beginConfiguration()

        if captureSession.canAddOutput(videoDataOutput) {
            captureSession.addOutput(videoDataOutput)
        }

        // to use CMGetAttachment in sampleBuffer
        if let captureConnection = videoDataOutput.connection(with: .video) {
            if captureConnection.isCameraIntrinsicMatrixDeliverySupported {
                captureConnection.isCameraIntrinsicMatrixDeliveryEnabled = true
            }
        }

        self.videoDataOutput = videoDataOutput
        self.videoDataOutputQueue = videoDataOutputQueue

        captureSession.commitConfiguration()
    }
}

extension CaptureSession: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let cameraIntrinsicData = CMGetAttachment(sampleBuffer, key: kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, attachmentModeOut: nil) else {
            return
        }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("Failed to obtain a CVPixelBuffer for the current output frame.")
            return
        }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let hight = CVPixelBufferGetHeight(pixelBuffer)
        print("width: \(width): hight:\(hight)")

        self.outputs.send(.init(cameraIntrinsicData: cameraIntrinsicData,
                                pixelBuffer: pixelBuffer,
                                pixelBufferSize: CGSize(width: width, height: hight)))
    }
}

// MARK: - AVCaptureVideoOrientation

extension AVCaptureVideoOrientation: CustomDebugStringConvertible
{
    public var debugDescription: String
    {
        switch self {
        case .portrait:
            return "portrait"
        case .portraitUpsideDown:
            return "portraitUpsideDown"
        case .landscapeRight:
            return "landscapeRight"
        case .landscapeLeft:
            return "landscapeLeft"
        @unknown default:
            return "unknown"
        }
    }

    public init?(deviceOrientation: UIDeviceOrientation)
    {
        switch deviceOrientation {
        case .portrait:
            self = .portrait
        case .portraitUpsideDown:
            self = .portraitUpsideDown
        case .landscapeLeft:
            self = .landscapeRight
        case .landscapeRight:
            self = .landscapeLeft
        case .faceUp,
             .faceDown,
             .unknown:
            return nil
        @unknown default:
            return nil
        }
    }

    public init?(interfaceOrientation: UIInterfaceOrientation)
    {
        switch interfaceOrientation {
        case .portrait:
            self = .portrait
        case .portraitUpsideDown:
            self = .portraitUpsideDown
        case .landscapeLeft:
            self = .landscapeLeft
        case .landscapeRight:
            self = .landscapeRight
        case .unknown:
            return nil
        @unknown default:
            return nil
        }
    }
}
