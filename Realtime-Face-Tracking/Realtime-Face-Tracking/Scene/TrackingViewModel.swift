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

final class TrackingViewModel: ObservableObject {

    let captureSession = CaptureSession()
    let visionClient = VisionClient()

    var previewLayer: AVCaptureVideoPreviewLayer {
        return captureSession.previewLayer
    }

    @Published var objectObservations: [VNDetectedObjectObservation] = []
    private var cancellables: Set<AnyCancellable> = []

    init() {
        bind()
    }

    @Published var pixelSize: CGSize = .zero

    func bind() {
        captureSession.outputs.map { output -> ([VNImageOption: AnyObject], CVImageBuffer, CGSize) in
            var requestHandlerOptions: [VNImageOption: AnyObject] = [:]
            let cameraIntrinsicData = CMGetAttachment(output.pixelBuffer, key: kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, attachmentModeOut: nil)
            if cameraIntrinsicData != nil {
                requestHandlerOptions[VNImageOption.cameraIntrinsics] = cameraIntrinsicData
            }
            return (requestHandlerOptions, output.pixelBuffer, output.pixelBufferSize)
        }
        .receive(on: RunLoop.main)
        .sink { [weak self] (options, pixelBuffer, pixelSize) in
            guard let self = self else { return }
            self.pixelSize = pixelSize
            self.visionClient.request(cvPixelBuffer: pixelBuffer,
                                      orientation: self.exifOrientationForDeviceOrientation(UIDevice.current.orientation),
                                      options: options)
        }
        .store(in: &cancellables)

        visionClient.$visionObjectObservations
            .receive(on: RunLoop.main)
            .assign(to: &$objectObservations)
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
