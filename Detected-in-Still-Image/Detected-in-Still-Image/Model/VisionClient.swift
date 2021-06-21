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
    case faceRect(rectBox: [CGRect])
    case faceLandmarks(drawPoints: [[Bool: [CGPoint]]])
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
    @Published var error: Error?

    func request(type: VisionRequestTypes.Set, imageViewFrame: CGRect) {
        self.requestTypes = type
        self.imageViewFrame = imageViewFrame
    }

    // MARK: Vision Requests
    lazy var faceDetectionRequest = VNDetectFaceRectanglesRequest(completionHandler: { [weak self] request, error in
        guard let self = self else { return }
        if let error = error {
            print(error.localizedDescription)
            self.error = error
            return
        }

        guard let results = request.results as? [VNFaceObservation] else {
            return
        }

        let rectBoxs = results.map { observation -> CGRect in
            let rectBox = self.boundingBox(forRegionOfInterest: observation.boundingBox, withinImageBounds: self.imageViewFrame)
            print("detected Rect: \(rectBox.debugDescription)")
            return rectBox
        }
        self.result = .faceRect(rectBox: rectBoxs)
    })

    lazy var faceLandmarkRequest = VNDetectFaceLandmarksRequest(completionHandler: { [weak self] request, error in
        guard let self = self else { return }
        if let error = error {
            print(error.localizedDescription)
            return
        }

        guard let results = request.results as? [VNFaceObservation] else {
            return
        }
        let points = self.makeFaceFeaturesPoints(onFaces: results, onImageWithBounds: self.imageViewFrame)
        self.result = .faceLandmarks(drawPoints: points)
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

    private func makeFaceFeaturesPoints(onFaces faces: [VNFaceObservation], onImageWithBounds bounds: CGRect) -> [[Bool: [CGPoint]]] {
        var landmarkPoints: [[Bool: [CGPoint]]] = []
        
        for face in faces {
            let faceBounds = boundingBox(forRegionOfInterest: face.boundingBox, withinImageBounds: bounds)
            guard let landmarks = face.landmarks else {
                return []
            }

            let openLandmarkRegions = [
                landmarks.leftEyebrow,
                landmarks.rightEyebrow,
                landmarks.faceContour,
                landmarks.noseCrest,
                landmarks.medianLine
            ].compactMap { $0 }

            // Draw eyes, lips, and nose as closed regions.
            let closedLandmarkRegions = [
                landmarks.leftEye,
                landmarks.rightEye,
                landmarks.outerLips,
                landmarks.innerLips,
                landmarks.nose
                ].compactMap { $0 }

            let openLandmarkPoints = openLandmarkRegions.compactMap { region -> [Bool: [CGPoint]]? in
                guard let points = self.makeNormalizedPoints(region: region, faceBounds: faceBounds) else {
                    return nil
                }
                return [false: points]
            }

            landmarkPoints += openLandmarkPoints

            let closedLandmarksPoints = closedLandmarkRegions.compactMap { region -> [Bool: [CGPoint]]? in
                guard let points = self.makeNormalizedPoints(region: region, faceBounds: faceBounds) else {
                    return nil
                }
                return [true: points]
            }

            landmarkPoints += closedLandmarksPoints
        }

        return landmarkPoints
    }

    private func makeNormalizedPoints(region: VNFaceLandmarkRegion2D, faceBounds: CGRect) -> [CGPoint]? {
        guard region.pointCount > 1 else {
            return nil
        }
        let points = region.normalizedPoints.map { point -> CGPoint in
            let x = point.x * faceBounds.width + faceBounds.origin.x
            let y = point.y * faceBounds.height + faceBounds.origin.y
            return CGPoint(x: x, y: y)
        }
        return points
    }
}