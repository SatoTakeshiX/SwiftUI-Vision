//
//  VisionClient.swift
//  Realtime-Face-Tracking
//
//  Created by satoutakeshi on 2021/06/04.
//

import Foundation
import Vision
import Combine

final class VisionClient: NSObject, ObservableObject {
    enum Mode {
        case faceLandmark // appleのものと一緒
        case faceDetection
        case tracking
    }

    @Published var visionResults: [VNFaceObservation] = []

    // Vision requests
    private var detectionRequests: [VNDetectFaceRectanglesRequest]? // output
    private var trackingRequests: [VNTrackObjectRequest]? // output

    private lazy var sequenceRequestHandler = VNSequenceRequestHandler()
    private let mode: Mode
    init(mode: Mode) {
        self.mode = mode
        super.init()
        setup()
    }

    func request(cvPixelBuffer pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation, options: [VNImageOption : Any] = [:]) {

        guard let trackingRequests = trackingRequests else {
            initialRequest(cvPixelBuffer: pixelBuffer, orientation: orientation, options: options)
            return
        }

        do {
            try sequenceRequestHandler.perform(trackingRequests, on: pixelBuffer, orientation: orientation)


        } catch {
            print(error.localizedDescription)
        }

        // Setup the next round of tracking.
        var newTrackingRequests = [VNTrackObjectRequest]()
        for trackingRequest in trackingRequests {
            print("\(#function)_after_sequence_\(trackingRequest.results?.count ?? 0)")

            guard let results = trackingRequest.results else {
                return
            }

            guard let observation = results[0] as? VNDetectedObjectObservation else {
                return
            }

            if !trackingRequest.isLastFrame {
                if observation.confidence > 0.3 {
                    trackingRequest.inputObservation = observation
                } else {
                    trackingRequest.isLastFrame = true
                }
                newTrackingRequests.append(trackingRequest)
            }


        }
        self.trackingRequests = newTrackingRequests

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

                // Perform all UI updates (drawing) on the main queue, not the background queue on which this handler is being called.
                DispatchQueue.main.async {
                    self.visionResults = results
                }
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

    private func setup() {
        prepareVisionRequest()
    }

    // MARK: Performing Vision Requests

    /// - Tag: WriteCompletionHandler
    fileprivate func prepareVisionRequest() {

        //self.trackingRequests = []
        // リクエストを作る
        var requests = [VNTrackObjectRequest]()

        // requestは単体のモデルなのか。

        // VNDetectFaceRectanglesRequestが顔の矩形を検知するリクエスト
        // 引数はcompletionHandlerしかない。
        let faceDetectionRequest = VNDetectFaceRectanglesRequest(completionHandler: { (request, error) in

            if error != nil {
                print("FaceDetection error: \(String(describing: error)).")
            }

            // handlerにrequest自体のオブジェクトがある。
            // requestにresultsが紐付いている
            guard let faceDetectionRequest = request as? VNDetectFaceRectanglesRequest,
                  let results = faceDetectionRequest.results as? [VNFaceObservation] else {
                return
            }
            // resultにVNTrackObjectRequestを作る
            //
            DispatchQueue.main.async {
                // Add the observations to the tracking list
                for observation in results {
                    // VNTrackObjectRequestは何するrequstだ？
                    let faceTrackingRequest = VNTrackObjectRequest(detectedObjectObservation: observation)
                    requests.append(faceTrackingRequest)
                }
                self.trackingRequests = requests
            }
        })

        // Start with detection.  Find face, then track it.
        self.detectionRequests = [faceDetectionRequest]

        self.sequenceRequestHandler = VNSequenceRequestHandler()
    }

    private func initialRequest(cvPixelBuffer pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation, options: [VNImageOption : Any] = [:]) {
        // guard let requests = self.trackingRequests, !requests.isEmpty else {
        // No tracking object detected, so perform initial detection
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                                        orientation: orientation,
                                                        options: options)

        do {
            // detectionRequestsは作ってある。
            // prepareVisionRequest
            // 一番最初はここが呼ばれる。no tracking object
            guard let detectRequests = self.detectionRequests else {
                return
            }
            try imageRequestHandler.perform(detectRequests)
        } catch let error as NSError {
            NSLog("Failed to perform FaceRectangleRequest: %@", error)
        }
    }
}
