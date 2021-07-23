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

    var pixelSize: CGSize = .zero

    func bind() {
        captureSession.outputs.map { output -> ([VNImageOption: AnyObject], CVImageBuffer, CGSize) in
            var requestHandlerOptions: [VNImageOption: AnyObject] = [:]
            let cameraIntrinsicData = CMGetAttachment(output.pixelBuffer, key: kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, attachmentModeOut: nil)
            if cameraIntrinsicData != nil {
                requestHandlerOptions[VNImageOption.cameraIntrinsics] = cameraIntrinsicData
            }
            return (requestHandlerOptions, output.pixelBuffer, output.pixelBufferSize)
        }
        .sink { [weak self] (options, pixelBuffer, pixelSize) in
            guard let self = self else { return }
            self.pixelSize = pixelSize
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
        previewLayer.sublayers?.removeSubrange(1...)
        let captureDeviceResolution = self.pixelSize

        let captureDeviceBounds = CGRect(x: 0,
                                         y: 0,
                                         width: captureDeviceResolution.width,
                                         height: captureDeviceResolution.height)

        let captureDeviceBoundsCenterPoint = CGPoint(x: captureDeviceBounds.midX,
                                                     y: captureDeviceBounds.midY)

        let normalizedCenterPoint = CGPoint(x: 0.5, y: 0.5)
        let overlayLayer = CALayer()
        overlayLayer.name = "DetectionOverlay"
        overlayLayer.masksToBounds = true
        overlayLayer.anchorPoint = normalizedCenterPoint
        overlayLayer.bounds = captureDeviceBounds
        overlayLayer.position = captureDeviceBoundsCenterPoint//CGPoint(x: previewLayer.bounds.midX, y: previewLayer.bounds.midY)
        overlayLayer.borderColor = UIColor.blue.cgColor
        overlayLayer.borderWidth = 4

        let videoPreviewRect = previewLayer.layerRectConverted(fromMetadataOutputRect: CGRect(x: 0, y: 0, width: 1, height: 1))
        var rotation: CGFloat
        var scaleX: CGFloat
        var scaleY: CGFloat

        // Rotate the layer into screen orientation.
        switch UIDevice.current.orientation {
        case .portraitUpsideDown:
            rotation = 180
            scaleX = videoPreviewRect.width / captureDeviceResolution.width
            scaleY = videoPreviewRect.height / captureDeviceResolution.height

        case .landscapeLeft:
            rotation = 90
            scaleX = videoPreviewRect.height / captureDeviceResolution.width
            scaleY = scaleX

        case .landscapeRight:
            rotation = -90
            scaleX = videoPreviewRect.height / captureDeviceResolution.width
            scaleY = scaleX

        default:
            rotation = 0
            scaleX = videoPreviewRect.width / captureDeviceResolution.width
            scaleY = videoPreviewRect.height / captureDeviceResolution.height
        }

        // Scale and mirror the image to ensure upright presentation.
        let affineTransform = CGAffineTransform(rotationAngle: radiansForDegrees(rotation))
            .scaledBy(x: scaleX, y: -scaleY)
        overlayLayer.setAffineTransform(affineTransform)
        overlayLayer.position = CGPoint(x: previewLayer.bounds.midX, y: previewLayer.bounds.midY)

        previewLayer.addSublayer(overlayLayer)

        guard let observation = faceObservations.first else { return }
        let xMin = observation.boundingBox.minX
        let yMax = observation.boundingBox.maxY

        var xCoord = xMin * overlayLayer.frame.size.width
        let yCoord = (1 - yMax) * overlayLayer.frame.size.height // これがどういうことだったかをもう一度理解する
        let width = observation.boundingBox.width * overlayLayer.frame.size.width
        let height = observation.boundingBox.height * overlayLayer.frame.size.height

        let subfromCenter = xCoord - overlayLayer.frame.midX
        let mirrerdMaxX = overlayLayer.frame.midX - subfromCenter
        xCoord = mirrerdMaxX - width

        let layer = CALayer()
        layer.frame = CGRect(x: xMin * overlayLayer.frame.size.width + overlayLayer.frame.minX, y: yCoord, width: width, height: height)
        layer.borderWidth = 2.0
        layer.borderColor = UIColor.green.cgColor

        previewLayer.addSublayer(layer)
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
