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

    @Published var detectedRects: [CGRect] = []
    private var cancellables: Set<AnyCancellable> = []

    init() {
        bind()
    }

    @Published var pixelSize: CGSize = .zero

    func bind() {
        captureSession.outputs
            .receive(on: RunLoop.main)
            .sink { [weak self] output in
                guard let self = self else { return }
                var requestHandlerOptions: [VNImageOption: AnyObject] = [:]
                // 内部データをVisionリクエストにオプションとして設定
                requestHandlerOptions[VNImageOption.cameraIntrinsics] = output.cameraIntrinsicData
                // 画像サイズは保持する
                self.pixelSize = output.pixelBufferSize
                self.visionClient.request(cvPixelBuffer: output.pixelBuffer,
                                          orientation: self.makeOrientation(with: UIDevice.current.orientation),
                                          options: requestHandlerOptions)
            }
            .store(in: &cancellables)

        visionClient.$visionObjectObservations
            .receive(on: RunLoop.main)
            .map { observations -> [CGRect] in
                return observations.map { $0.boundingBox }
            }
            .assign(to: &$detectedRects)
    }

    func startSession() {
        captureSession.startSettion()
    }

    func makeOrientation(with deviceOrientation: UIDeviceOrientation) -> CGImagePropertyOrientation {

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
