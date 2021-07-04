//
//  TrackingViewModel.swift
//  Realtime-Face-Tracking
//
//  Created by satoutakeshi on 2021/06/02.
//

import Combine
import UIKit
import Vision
import AVKit

protocol ViewModelable {
    associatedtype Output
    //var output: PassthroughSubject<Output, Never> { get set}
    var output: Output? { get set }
}

final class TrackingViewModel: ObservableObject, ViewModelable {

    struct Output {
        let faceRect: CGRect
    }

    let captureSession = CaptureSession()
    let visionClient = VisionClient()

    var previewLayer: AVCaptureVideoPreviewLayer {
        return captureSession.previewLayer
    }

    @Published var output: Output?
    private var cancellables: Set<AnyCancellable> = []

    init() {
        bind()
    }

    var resolution: CGSize = .zero

    func bind() {
        captureSession.outputs.map { output -> ([VNImageOption: AnyObject], CVImageBuffer) in
            var requestHandlerOptions: [VNImageOption: AnyObject] = [:]
            let cameraIntrinsicData = CMGetAttachment(output.pixelBuffer, key: kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, attachmentModeOut: nil)
            if cameraIntrinsicData != nil {
                requestHandlerOptions[VNImageOption.cameraIntrinsics] = cameraIntrinsicData
            }
            return (requestHandlerOptions, output.pixelBuffer)
        }
        .sink { [weak self] (options, pixelBuffer) in
            guard let self = self else { return }
            self.visionClient.request(cvPixelBuffer: pixelBuffer,
                                      orientation: self.exifOrientationForDeviceOrientation(UIDevice.current.orientation),
                                      options: options)
        }
        .store(in: &cancellables)

        visionClient.$visionFaceResults
            .receive(on: RunLoop.main)
            .sink { [weak self] observations in
            guard let self = self else { return }
            print(observations.description)
            self.drawFaceObservations(observations)
        }.store(in: &cancellables)
    }

    func startSession() {
        captureSession.startSettion()
    }

    func exifOrientationForDeviceOrientation(_ deviceOrientation: UIDeviceOrientation) -> CGImagePropertyOrientation {

        switch deviceOrientation {
        case .portraitUpsideDown:
            return .rightMirrored

        case .landscapeLeft:
            return .downMirrored

        case .landscapeRight:
            return .upMirrored

        default:
            return .leftMirrored
        }
    }

    let detectedLayer: CALayer = {
        let layer = CALayer()
        layer.backgroundColor = UIColor.red.cgColor
        layer.borderWidth = 4
        return layer

    }()
    func drawFaceObservations(_ faceObservations: [VNFaceObservation]) {
        guard let obs = faceObservations.first else { return }
        let rect = convertBoundingBox(obs.boundingBox, deviceOrientation: UIDevice.current.orientation)
        let convertedRect = self.previewLayer.layerRectConverted(fromMetadataOutputRect: rect)
        output = Output(faceRect: convertedRect)
        detectedLayer.frame = convertedRect
        previewLayer.addSublayer(detectedLayer)
    }

    fileprivate func radiansForDegrees(_ degrees: CGFloat) -> CGFloat {
        return CGFloat(Double(degrees) * Double.pi / 180.0)
    }

    // MARK: - Vision boundingBox conversion

    /// - Parameters:
    ///   - boundingBox: `CGRect` that has scale values from 0 to 1 in current device orientation's coordinate with bottom-left origin.
    ///   - deviceOrientation: Current device orientation.
    /// - Returns: A new bounding box that has top-left origin in camera's coordinate, e.g. for passing to `AVCaptureVideoPreviewLayer.layerRectConverted`.
    func convertBoundingBox(_ boundingBox: CGRect, deviceOrientation: UIDeviceOrientation) -> CGRect
    {
        var boundingBox = boundingBox

        // Flip y-axis as `boundingBox.origin` starts from bottom-left.
        boundingBox.origin.y = 1 - boundingBox.origin.y - boundingBox.height

        switch deviceOrientation {
        case .portrait:
            // 90 deg clockwise
            boundingBox = boundingBox
                .applying(CGAffineTransform(translationX: -0.5, y: -0.5))
                .applying(CGAffineTransform(rotationAngle: -.pi / 2))
                .applying(CGAffineTransform(translationX: 0.5, y: 0.5))
        case .portraitUpsideDown:
            // 90 deg counter-clockwise
            boundingBox = boundingBox
                .applying(CGAffineTransform(translationX: -0.5, y: -0.5))
                .applying(CGAffineTransform(rotationAngle: .pi / 2))
                .applying(CGAffineTransform(translationX: 0.5, y: 0.5))
        case .landscapeLeft:
            break
        case .landscapeRight:
            // 180 deg
            boundingBox = boundingBox
                .applying(CGAffineTransform(translationX: -0.5, y: -0.5))
                .applying(CGAffineTransform(rotationAngle: .pi))
                .applying(CGAffineTransform(translationX: 0.5, y: 0.5))
        case .unknown,
             .faceUp,
             .faceDown:
            break
        @unknown default:
            break
        }

        return boundingBox
    }
}
