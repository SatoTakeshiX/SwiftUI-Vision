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
        /**
         in landmarkRegion: VNFaceLandmarkRegion2D,
                                    applying affineTransform: CGAffineTransform,
                                    closingWhenComplete closePath: Bool
         この3つが必要
         */
        //let landmarkRegion: VNFaceLandmarks2D
        let faceRect: CGRect
        //let affineTransform: CGAffineTransform
        //let closePath: Bool
    }

    let captureSession = CaptureSession()
    let visionClient = VisionClient(mode: .faceLandmark)

    var previewLayer: AVCaptureVideoPreviewLayer {
        return captureSession.previewLayer
    }

    //@Published var output: PassthroughSubject<Output, Never> = PassthroughSubject()
    @Published var output: Output?
    private var cancellables: Set<AnyCancellable> = []

    init() {
        bind()
    }

    var resolution: CGSize = .zero

    func bind() {
        captureSession.outputs.sink { [weak self] output in
            guard let self = self else { return }
            var requestHandlerOptions: [VNImageOption: AnyObject] = [:]
            let cameraIntrinsicData = CMGetAttachment(output.pixelBuffer, key: kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, attachmentModeOut: nil)
            if cameraIntrinsicData != nil {
                requestHandlerOptions[VNImageOption.cameraIntrinsics] = cameraIntrinsicData
            }
            self.visionClient.request(cvPixelBuffer: output.pixelBuffer,
                                      orientation: self.exifOrientationForDeviceOrientation(UIDevice.current.orientation),
                                      options: requestHandlerOptions)

        }.store(in: &cancellables)

        visionClient.$visionResults.sink { [weak self] observations in
            guard let self = self else { return }
            print(observations.description)
            /**
             [<VNFaceObservation: 0x101306090> FB43095B-8C93-4026-8206-D9BEEFF8B888 requestRevision=0 confidence=1.000000 timeRange={{0/1 = 0.000}, {0/1 = 0.000}} boundingBox=[0.156562, 0.26911, 0.537341, 0.43712] VNFaceLandmarks2D [VNRequestFaceLandmarksConstellation76Points, confidence=0.827271]]
             値は取れた。ここまではよし
             */
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
        /**
         pathはSwiftUIで扱う
         */

        guard let obs = faceObservations.first else { return }
        let rect = convertBoundingBox(obs.boundingBox, deviceOrientation: UIDevice.current.orientation)
        let convertedRect = self.previewLayer.layerRectConverted(fromMetadataOutputRect: rect)
        output = Output(faceRect: convertedRect)
        detectedLayer.frame = convertedRect
        previewLayer.addSublayer(detectedLayer)



//        for observation in faceObservations {
//            // appleでは端末の解像度を計算している
//            // iPhone 12 proで(4032.0, 3024.0)
//            // 他の人がどうやっているのかが気になる。
//            print(resolution.debugDescription) // (4032.0, 3024.0) on iPhone 12 Pro
//            let faceBounds = VNImageRectForNormalizedRect(observation.boundingBox, Int(resolution.width), Int(resolution.height))
//            output = .init(faceRect: faceBounds)
//
//            // ある方向に向けるとVisionのoutputが止まる。なんでだ？
//
//            let videoPreviewRect = previewLayer.layerRectConverted(fromMetadataOutputRect: CGRect(x: 0, y: 0, width: 1, height: 1))
//
//            var rotation: CGFloat
//            var scaleX: CGFloat
//            var scaleY: CGFloat
//
//            // Rotate the layer into screen orientation.
//            switch UIDevice.current.orientation {
//            case .portraitUpsideDown:
//                rotation = 180
//                scaleX = videoPreviewRect.width / resolution.width
//                scaleY = videoPreviewRect.height / resolution.height
//
//            case .landscapeLeft:
//                rotation = 90
//                scaleX = videoPreviewRect.height / resolution.width
//                scaleY = scaleX
//
//            case .landscapeRight:
//                rotation = -90
//                scaleX = videoPreviewRect.height / resolution.width
//                scaleY = scaleX
//
//            default:
//                rotation = 0
//                scaleX = videoPreviewRect.width / resolution.width
//                scaleY = videoPreviewRect.height / resolution.height
//            }
//
//            // Scale and mirror the image to ensure upright presentation.
//            let affineTransform = CGAffineTransform(rotationAngle: radiansForDegrees(rotation))
//                .scaledBy(x: scaleX, y: -scaleY)
//
//           // previewLayer.setAffineTransform(affineTransform)
//        }
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
