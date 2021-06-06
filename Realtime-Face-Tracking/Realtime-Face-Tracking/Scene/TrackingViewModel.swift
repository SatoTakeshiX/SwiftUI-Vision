//
//  TrackingViewModel.swift
//  Realtime-Face-Tracking
//
//  Created by satoutakeshi on 2021/06/02.
//

import Combine
import UIKit
import Vision

final class TrackingViewModel: ObservableObject {
    let captureSession = CaptureSession()
    let visionClient = VisionClient(mode: .faceLandmark)

    var previewLayer: CALayer {
        return captureSession.previewLayer
    }
    
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

        visionClient.$visionResults.sink { observations in
            print(observations.description)
            /**
             [<VNFaceObservation: 0x101306090> FB43095B-8C93-4026-8206-D9BEEFF8B888 requestRevision=0 confidence=1.000000 timeRange={{0/1 = 0.000}, {0/1 = 0.000}} boundingBox=[0.156562, 0.26911, 0.537341, 0.43712] VNFaceLandmarks2D [VNRequestFaceLandmarksConstellation76Points, confidence=0.827271]]
             値は取れた。ここまではよし
             */
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
}
