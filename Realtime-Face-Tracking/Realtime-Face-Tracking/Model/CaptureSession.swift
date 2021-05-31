//
//  CaptureSession.swift
//  Realtime-Face-Tracking
//
//  Created by satoutakeshi on 2021/05/31.
//

import Foundation
import AVKit

final class CaptureSession: NSObject, ObservableObject {
    private let captureSession = AVCaptureSession()
    private var captureDevice: AVCaptureDevice?

    private var videoDataOutput: AVCaptureVideoDataOutput?
    private var videoDataOutputQueue: DispatchQueue?
    @Published private(set) var previewLayer: AVCaptureVideoPreviewLayer?

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
                                                                  position: .back).devices.first {
            captureDevice = availableDevice
            do {
                let captureDeviceInput = try AVCaptureDeviceInput(device: availableDevice)
                captureSession.addInput(captureDeviceInput)
            } catch {
                print(error.localizedDescription)
            }
        }

        makePreviewLayser(session: captureSession)
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
        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        previewLayer.backgroundColor = UIColor.green.cgColor
        previewLayer.masksToBounds = true
        self.previewLayer = previewLayer
    }

    private func makeDataOutput() {
        let videoDataOutput = AVCaptureVideoDataOutput()
        // frame落ちたら捨てる処理
        videoDataOutput.alwaysDiscardsLateVideoFrames = true

        // Create a serial dispatch queue used for the sample buffer delegate as well as when a still image is captured.
        // A serial dispatch queue must be used to guarantee that video frames will be delivered in order.
        let videoDataOutputQueue = DispatchQueue(label: "com.Personal-Factory.Realtime-Face-Tracking")
        videoDataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)

        captureSession.beginConfiguration()

        if captureSession.canAddOutput(videoDataOutput) {
            for input in captureSession.inputs {
                captureSession.removeInput(input)
            }

                captureSession.addOutput(videoDataOutput)
            
        }

        // isEnable: Indicates whether the connection's output should consume data. このプロパティの値は、セッションの実行時にレシーバーの出力が接続された inputPort からのデータを消費するかどうかを決定する BOOL です。クライアントは、このプロパティを設定して、キャプチャ中に特定の出力へのデータの流れを停止できます。デフォルト値は YES です。
        videoDataOutput.connection(with: .video)?.isEnabled = true

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

    // Removes infrastructure for AVCapture as part of cleanup.
    private func teardownAVCapture() {
        self.videoDataOutput = nil
        self.videoDataOutputQueue = nil

        if let previewLayer = previewLayer {
            previewLayer.removeFromSuperlayer()
            self.previewLayer = nil
        }
    }
}

extension CaptureSession: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {

    }
}
