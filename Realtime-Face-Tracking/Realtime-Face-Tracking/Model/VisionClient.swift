//
//  VisionClient.swift
//  Realtime-Face-Tracking
//
//  Created by satoutakeshi on 2021/06/04.
//

import Foundation
import Vision
import Combine

// tracking face via CVPixelBuffer
final class VisionClient: NSObject, ObservableObject {

    enum State {
        case stop
        case tracking(trackingRequests: [VNTrackObjectRequest])
    }
    @Published var visionObjectObservations: [VNDetectedObjectObservation] = []
    @Published var state: State = .stop

    // Vision requests
    private var detectionRequests: [VNDetectFaceRectanglesRequest]? // output
    private var trackingRequests: [VNTrackObjectRequest]? // output
    private var subscriber: Set<AnyCancellable> = []

    private lazy var sequenceRequestHandler = VNSequenceRequestHandler()
    override init() {
        super.init()
        setup()
    }

    func request(cvPixelBuffer pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation, options: [VNImageOption : Any] = [:]) {

        switch state {
            case .stop:
                initialRequest(cvPixelBuffer: pixelBuffer, orientation: orientation, options: options)
            case .tracking(let trackingRequests):
                guard !trackingRequests.isEmpty else {
                    initialRequest(cvPixelBuffer: pixelBuffer, orientation: orientation, options: options)
                    break
                }
                do {
                    try sequenceRequestHandler.perform(trackingRequests, on: pixelBuffer, orientation: orientation)
                } catch {
                    print(error.localizedDescription)
                }

                // 次のトラッキングを設定
                // perform実行後はresultsプロパティが更新されている
                let newTrackingRequests = trackingRequests.compactMap { request -> VNTrackObjectRequest? in
                    guard let results = request.results else {
                        return nil
                    }

                    guard let observation = results[0] as? VNDetectedObjectObservation else {
                        return nil
                    }

                    if !request.isLastFrame {
                        if observation.confidence > 0.3 {
                            request.inputObservation = observation

                        } else {
                            request.isLastFrame = true
                        }
                        return request
                    } else {
                        return nil
                    }
                }

                state = .tracking(trackingRequests: newTrackingRequests)

                if newTrackingRequests.isEmpty {
                    // トラックするものがない
                    self.visionObjectObservations = []
                    return
                }

                newTrackingRequests.forEach { request in
                    guard let result = request.results as? [VNDetectedObjectObservation] else { return }
                    self.visionObjectObservations = result
                }
        }
    }

    private func setup() {
        let faceDetectionRequest = prepareRequest() { [weak self] result in
            switch result {
                case .success(let trackingRequests):
                    self?.state = .tracking(trackingRequests: trackingRequests)
                    self?.trackingRequests = trackingRequests
                case .failure(let error):
                    print("FaceDetection error: \(String(describing: error)).")
            }
        }

        self.detectionRequests = [faceDetectionRequest]
        self.sequenceRequestHandler = VNSequenceRequestHandler()
    }

    // MARK: Performing Vision Requests
    private func prepareRequest(completion: @escaping (Result<[VNTrackObjectRequest], Error>) -> Void) -> VNDetectFaceRectanglesRequest {
        var requests = [VNTrackObjectRequest]()
        let faceRequest = VNDetectFaceRectanglesRequest(completionHandler: { (request, error) in
            if let error = error {
                completion(.failure(error))
            }
            guard let faceDetectionRequest = request as? VNDetectFaceRectanglesRequest,
                  let results = faceDetectionRequest.results as? [VNFaceObservation] else {
                return
            }

            // Add the observations to the tracking list
            for obs in results {
                let faceTrackingRequest = VNTrackObjectRequest(detectedObjectObservation: obs)
                requests.append(faceTrackingRequest)
            }
            self.trackingRequests = requests
            completion(.success(requests))

        })
        return faceRequest
    }

    private func initialRequest(cvPixelBuffer pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation, options: [VNImageOption : Any] = [:]) {
        // No tracking object detected, so perform initial detection
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                                        orientation: orientation,
                                                        options: options)
        do {
            guard let detectRequests = self.detectionRequests else {
                return
            }
            try imageRequestHandler.perform(detectRequests)
        } catch let error as NSError {
            NSLog("Failed to perform FaceRectangleRequest: %@", error)
        }
    }
}
