//
//  TrackingViewModel.swift
//  Realtime-Face-Tracking
//
//  Created by satoutakeshi on 2021/06/02.
//

import Combine
import UIKit
import Vision

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

    var previewLayer: CALayer {
        return captureSession.previewLayer
    }

    //@Published var output: PassthroughSubject<Output, Never> = PassthroughSubject()
    @Published var output: Output?
    private var cancellables: Set<AnyCancellable> = []

    init() {
        bind()
    }

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

    func drawFaceObservations(_ faceObservations: [VNFaceObservation]) {

        /**
         in landmarkRegion: VNFaceLandmarkRegion2D,
                                    applying affineTransform: CGAffineTransform,
                                    closingWhenComplete closePath: Bool
         この3つが必要
         */


        /**
         pathはSwiftUIで扱う
         */

        for observation in faceObservations {
            // appleでは端末の解像度を計算している
            // iPhone 12 proで(4032.0, 3024.0)
            // UIScreen.mainは足りない：width_1170.0_height:2532.0
            // UIScreen.main.nativeBounds, UIScreen.main.nativeSlace：width_3510.0_height:7596.0
            let deviceRect = UIScreen.main.bounds
            let scale = UIScreen.main.scale

            let faceBounds = VNImageRectForNormalizedRect(observation.boundingBox, Int(deviceRect.width * scale), Int(deviceRect.height * scale))

            output = .init(faceRect: faceBounds)
        }



        
    }
}
