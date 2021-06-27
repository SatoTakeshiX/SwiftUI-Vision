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
    case faceRect(rectBox: [CGRect], info: [[String: String]])
    case faceLandmarks(drawPoints: [[Bool: [CGPoint]]], info: [[String: String]])
    case word(rectBox: [CGRect], info: [[String: String]])
    case character(rectBox: [CGRect], info: [[String: String]])
    case textRecognize(info: [[String: String]])
    case barcode(rectBox: [CGRect], info: [[String: String]])
    case rect(rectBox: [CGRect], info: [[String: String]])

    struct Set: OptionSet {
        typealias Element = VisionRequestTypes.Set
        let rawValue: Int8
        init(rawValue: Int8) {
            self.rawValue = rawValue
        }

        static let faceRect         = Set(rawValue: 1 << 0)
        static let faceLandmarks    = Set(rawValue: 1 << 1)
        static let text             = Set(rawValue: 1 << 2)
        static let textRecognize    = Set(rawValue: 1 << 3)
        static let barcode          = Set(rawValue: 1 << 4)
        static let rect             = Set(rawValue: 1 << 5)

        static let all: Set         = [.faceRect,
                                       .faceLandmarks,
                                       .text,
                                       .barcode,
                                       .rect]
    }
}

final class VisionClient: ObservableObject {

    enum VisionError: Error {
        case typeNotSet
        case visionError(error: Error)
    }

    private var requestTypes: VisionRequestTypes.Set = []
    private var imageViewFrame: CGRect = .zero

    /// ensure in main thread when you use the value
    @Published var result: VisionRequestTypes = .unknown
    @Published var error: VisionError?

    func configure(type: VisionRequestTypes.Set, imageViewFrame: CGRect) {
        self.requestTypes = type
        self.imageViewFrame = imageViewFrame
    }

    func performVisionRequest(image: CGImage,
                              orientation: CGImagePropertyOrientation) {
        guard !requestTypes.isEmpty else {
            error = VisionError.typeNotSet
            return 
        }
        let imageRequestHandler = VNImageRequestHandler(cgImage: image,
                                                        orientation: orientation,
                                                        options: [:])

        let requests = makeImageRequests()
        do {
            try imageRequestHandler.perform(requests)
        } catch {
            self.error = VisionError.visionError(error: error)
        }
    }

    private func makeImageRequests() -> [VNRequest] {
        var requests: [VNRequest] = []
        if requestTypes.contains(.faceRect) {
            requests.append(faceDetectionRequest)
        }

        if requestTypes.contains(.faceLandmarks) {
            requests.append(faceLandmarkRequest)
        }

        if requestTypes.contains(.text) {
            requests.append(textDetectionRequest)
        }

        if requestTypes.contains(.textRecognize) {
            requests.append(textRecognizeRequest)
        }

        if requestTypes.contains(.barcode) {
            requests.append(barcodeDetectionRequest)
        }

        if requestTypes.contains(.rect) {
            requests.append(rectDetectionRequest)
        }

        return requests
    }

    // MARK: Vision Requests
    lazy var faceDetectionRequest = VNDetectFaceRectanglesRequest(completionHandler: { [weak self] request, error in
        guard let self = self else { return }
        if let error = error {
            print(error.localizedDescription)
            self.error = VisionError.visionError(error: error)
            return
        }

        guard let results = request.results as? [VNFaceObservation] else {
            return
        }

        let rectBoxes = results.map { observation -> CGRect in
            let rectBox = self.boundingBox(forRegionOfInterest: observation.boundingBox, withinImageBounds: self.imageViewFrame)
            print("detected Rect: \(rectBox.debugDescription)")
            return rectBox
        }

        var info = results.map { obsevation -> [String: String] in
            var info: [String: String] = [:]
            info["roll"] = "\(obsevation.roll?.doubleValue ?? 0)"
            info["yaw"] = "\(obsevation.yaw?.doubleValue ?? 0)"
            return info
        }
        info.append(["face count": "\(results.count)"])
        self.result = .faceRect(rectBox: rectBoxes, info: info)
    })

    lazy var faceLandmarkRequest = VNDetectFaceLandmarksRequest(completionHandler: { [weak self] request, error in
        guard let self = self else { return }
        if let error = error {
            print(error.localizedDescription)
            self.error = VisionError.visionError(error: error)
            return
        }

        guard let results = request.results as? [VNFaceObservation] else {
            return
        }
        let points = self.makeFaceFeaturesPoints(onFaces: results, onImageWithBounds: self.imageViewFrame)
        var info = results.map { obsevation -> [String: String] in
            var info: [String: String] = [:]
            info["roll"] = "\(obsevation.roll?.doubleValue ?? 0)"
            info["yaw"] = "\(obsevation.yaw?.doubleValue ?? 0)"
            return info
        }
        info.append(["face count": "\(results.count)"])
        self.result = .faceLandmarks(drawPoints: points, info: info)
    })

    lazy var textDetectionRequest: VNDetectTextRectanglesRequest = {
        let textDetectRequest = VNDetectTextRectanglesRequest(completionHandler: { [weak self] request, error in
            guard let self = self else { return }
            if let error = error {
                print(error.localizedDescription)
                self.error = VisionError.visionError(error: error)
                return
            }

            guard let results = request.results as? [VNTextObservation] else {
                return
            }

            let wordBoxes = results.map { observation -> CGRect in
                let rectBox = self.boundingBox(forRegionOfInterest: observation.boundingBox, withinImageBounds: self.imageViewFrame)
                print("detected Rect: \(rectBox.debugDescription)")
                return rectBox
            }
            let wordInfo = ["wordBoxes count": "\(results.count)"]
            self.result = .word(rectBox: wordBoxes, info: [wordInfo])

            let charRects = self.makeTextRect(textObservations: results, onImageWithBounds: self.imageViewFrame)
            let charInfo = ["char count": "\(charRects.count)"]
            self.result = .character(rectBox: charRects, info: [charInfo])
        })
        // Tell Vision to report bounding box around each character.
        textDetectRequest.reportCharacterBoxes = true
        return textDetectRequest
    }()

    lazy var textRecognizeRequest: VNRecognizeTextRequest = {
        let textRecognizeRequest = VNRecognizeTextRequest { [weak self] request, error in
            guard let self = self else { return }
            if let error = error {
                print(error.localizedDescription)
                self.error = VisionError.visionError(error: error)
            }

            guard let results = request.results as? [VNRecognizedTextObservation] else {
                return
            }
            let candidatesTexts = results.compactMap { observation -> [String]? in
                guard observation.confidence > 0.3 else { return nil }
                let recognizedTexts = observation.topCandidates(3)
                return recognizedTexts.map { $0.string }
            }

            let info = candidatesTexts.compactMap { strings -> [String: String] in
                var output: [String: String] = [:]
                for (index, string) in strings.enumerated() {
                    output["candiate \(index)"] = string
                }
                return output
            }
            self.result = .textRecognize(info: info)
        }

        textRecognizeRequest.recognitionLevel = .fast
        return textRecognizeRequest
    }()

    lazy var barcodeDetectionRequest: VNDetectBarcodesRequest = {
        let barcodeRequest = VNDetectBarcodesRequest(completionHandler: { [weak self] request, error in
            guard let self = self else { return }
            if let error = error {
                print(error.localizedDescription)
                self.error = VisionError.visionError(error: error)
                return
            }

            guard let results = request.results as? [VNBarcodeObservation] else {
                return
            }

            let rectBoxes = results.map { observation -> CGRect in
                let rectBox = self.boundingBox(forRegionOfInterest: observation.boundingBox, withinImageBounds: self.imageViewFrame)
                print("detected Rect: \(rectBox.debugDescription)")
                return rectBox
            }

            let info = results.map { obsevation -> [String: String] in
                var detectedInfo: [String: String] = [:]
                detectedInfo["symbology"] = obsevation.symbology.rawValue
                detectedInfo["value"] = obsevation.payloadStringValue ?? ""
                return detectedInfo
            }
            self.result = .barcode(rectBox: rectBoxes, info: info)
        })
        barcodeRequest.symbologies = [.QR]
        return barcodeRequest

    }()

    lazy var rectDetectionRequest: VNDetectRectanglesRequest = {
        let rectDetectRequest = VNDetectRectanglesRequest { [weak self] request, error in
            guard let self = self else { return }
            if let error = error {
                print(error.localizedDescription)
                self.error = VisionError.visionError(error: error)
                return
            }

            guard let results = request.results as? [VNRectangleObservation] else {
                return
            }

            let rectBoxes = results.map { observation -> CGRect in
                let rectBox = self.boundingBox(forRegionOfInterest: observation.boundingBox, withinImageBounds: self.imageViewFrame)
                print("detected Rec: \(rectBox.debugDescription)")
                return rectBox
            }

            let info = ["detected count": "\(results.count)"]
            self.result = .rect(rectBox: rectBoxes, info: [info])
        }

        return rectDetectRequest
    }()

    // MARK: - Private
    private func boundingBox(forRegionOfInterest: CGRect,
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

    // MARK: - Text Detection
    private func makeTextRect(textObservations: [VNTextObservation], onImageWithBounds bounds: CGRect) -> [CGRect] {
        let charBoxRects = textObservations.compactMap { observation -> [CGRect]? in
            guard let charBoxes = observation.characterBoxes else {
                return nil
            }

            return charBoxes.compactMap { charObservation in
                self.boundingBox(forRegionOfInterest: charObservation.boundingBox, withinImageBounds: bounds)
            }
        }
        return charBoxRects.flatMap { $0 }
    }

    // MARK: - Text Recoginaze

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
