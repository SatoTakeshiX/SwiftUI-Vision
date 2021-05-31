//
//  CaptureSession.swift
//  Realtime-Face-Tracking
//
//  Created by satoutakeshi on 2021/05/31.
//

import Foundation
import AVKit

final class CaptureSession: NSObject {
    private let captureSession = AVCaptureSession()
    private var captureDevice: AVCaptureDevice?

    private var videoDataOutput: AVCaptureVideoDataOutput?
    private var videoDataOutputQueue: DispatchQueue?
    private(set) var previewLayer: AVCaptureVideoPreviewLayer?

    /// MARK: - Create capture session
    func setupCaptureSession() {

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
        makeDataOutput()
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

        if captureSession.canAddOutput(videoDataOutput) {
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
