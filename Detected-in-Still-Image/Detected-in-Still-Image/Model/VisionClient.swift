//
//  VisionClient.swift
//  Detected-in-Still-Image
//
//  Created by satoutakeshi on 2021/06/20.
//

import Foundation
import Vision

enum VisionRequestTypes {
    case unknown
    case faceRect(rectBox: CGRect)
    case faceLandmarks(observation: [VNFaceObservation])
    case text
    case barcode
    case rect

    struct Set: OptionSet {
        typealias Element = VisionRequestTypes.Set
        let rawValue: Int8
        init(rawValue: Int8) {
            self.rawValue = rawValue
        }

        static let faceRect         = Set(rawValue: 1 << 0)
        static let faceLandmarks    = Set(rawValue: 1 << 1)
        static let text             = Set(rawValue: 1 << 2)
        static let barcode          = Set(rawValue: 1 << 3)
        static let rect             = Set(rawValue: 1 << 4)

        static let all: Set         = [.faceRect,
                                       .faceLandmarks,
                                       .text,
                                       .barcode,
                                       .rect]
    }
}

final class VisionClient: ObservableObject {

    private var requestTypes: VisionRequestTypes.Set = []
    private var imageViewFrame: CGRect = .zero

    /// ensure in main thread when you use the value
    @Published var result: VisionRequestTypes = .unknown

    func configure(_ requests: VisionRequestTypes.Set, imageViewFrame: CGRect) {
        self.requestTypes = requests
        self.imageViewFrame = imageViewFrame
    }

    // MARK: Vision Requests
    lazy var faceDetectionRequest = VNDetectFaceRectanglesRequest(completionHandler: { request, error in
        if let error = error {
            print(error.localizedDescription)
            return
        }

        guard let results = request.results as? [VNFaceObservation] else {
            return
        }


    })

    lazy var faceLandmarkRequest = VNDetectFaceLandmarksRequest(completionHandler: { request, error in
        if let error = error {
            print(error.localizedDescription)
            return
        }

        guard let results = request.results as? [VNFaceObservation] else {
            return
        }
        // need to use in main thread
        self.result = .faceLandmarks(observation: results)
    })

    func boundingBox(forRegionOfInterest: CGRect,
                     withinImageBounds bounds: CGRect) -> CGRect {

        let imageWidth = bounds.width
        let imageHeight = bounds.height

        // Begin with input rect.
        var rect = forRegionOfInterest

        // Reposition origin.
        rect.origin.x *= imageWidth
        rect.origin.x += bounds.origin.x
        //
        rect.origin.y = (rect.origin.y) * imageHeight + bounds.origin.y

        // Rescale normalized coordinates.
        rect.size.width *= imageWidth
        rect.size.height *= imageHeight

        return rect
    }
}
