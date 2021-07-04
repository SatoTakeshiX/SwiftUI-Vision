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

//        var detectionRequests: [VNDetectFaceRectanglesRequest]? {
//            switch self {
//                case .faceDetected(let trackingRequests, let ):
//                    return detectionRequests
//                default:
//                    return nil
//            }
//        }
    }
    @Published var visionFaceResults: [VNFaceObservation] = []
    @Published var state: State = .stop

    // Vision requests
    private var detectionRequests: [VNDetectFaceRectanglesRequest]? // output
    private var trackingRequests: [VNTrackObjectRequest]? // output
    private var subscriber: Set<AnyCancellable> = []

    private lazy var sequenceRequestHandler = VNSequenceRequestHandler()
    override init() {
        super.init()
        setup()
        bind()
    }

    func bind() {
        $state.sink { [weak self] state in
            guard let self = self else { return }
            switch state {
                case .stop:
                    break
                case .tracking(let trackingRequests):
                    break
            }

        }.store(in: &subscriber)
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
                // Setup the next round of tracking.

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
                    // Nothing to track, so abort.
                    return
                }

                // Perform face landmark tracking on detected faces.
                var faceLandmarkRequests = [VNDetectFaceLandmarksRequest]()

                // Perform landmark detection on tracked faces.
                for trackingRequest in newTrackingRequests {

                    let faceLandmarksRequest = VNDetectFaceLandmarksRequest(completionHandler: { (request, error) in

                        if error != nil {
                            print("FaceLandmarks error: \(String(describing: error)).")
                        }

                        guard let landmarksRequest = request as? VNDetectFaceLandmarksRequest,
                            let results = landmarksRequest.results as? [VNFaceObservation] else {
                                return
                        }

                        self.visionFaceResults = results
                    })

                    guard let trackingResults = trackingRequest.results else {
                        return
                    }

                    guard let observation = trackingResults[0] as? VNDetectedObjectObservation else {
                        return
                    }
                    let faceObservation = VNFaceObservation(boundingBox: observation.boundingBox)
                    faceLandmarksRequest.inputFaceObservations = [faceObservation]

                    // Continue to track detected facial landmarks.
                    faceLandmarkRequests.append(faceLandmarksRequest)

                    let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                                                    orientation: orientation,
                                                                    options: options)

                    do {
                        try imageRequestHandler.perform(faceLandmarkRequests)
                    } catch let error as NSError {
                        NSLog("Failed to perform FaceLandmarkRequest: %@", error)
                    }
                }
        }
    }

    private func setup() {
        let faceDetectionRequest = prepareVisionRequest() { [weak self] result in
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

    /// - Tag: WriteCompletionHandler
    fileprivate func prepareVisionRequest(completion: @escaping (Result<[VNTrackObjectRequest], Error>) -> Void) -> VNDetectFaceRectanglesRequest {
        var requests = [VNTrackObjectRequest]()
        let faceDetectionRequest = VNDetectFaceRectanglesRequest(completionHandler: { (request, error) in
            if let error = error {
                completion(.failure(error))
            }
            guard let faceDetectionRequest = request as? VNDetectFaceRectanglesRequest,
                  let results = faceDetectionRequest.results as? [VNFaceObservation] else {
                return
            }

            // Add the observations to the tracking list
            for observation in results {
                let faceTrackingRequest = VNTrackObjectRequest(detectedObjectObservation: observation)
                requests.append(faceTrackingRequest)
            }
            self.trackingRequests = requests
            completion(.success(requests))

        })
        return faceDetectionRequest
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
