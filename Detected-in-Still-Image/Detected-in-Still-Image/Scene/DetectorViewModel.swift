//
//  DetectorViewModel.swift
//  Detected-in-Still-Image
//
//  Created by satoutakeshi on 2021/06/17.
//

import Foundation
import SwiftUI
import UIKit
import Vision

final class DetectorViewModel: ObservableObject {

    @Published var image: UIImage = UIImage()
    @Published var imageViewFrame: CGRect = .zero
    @Published var detectedFrame: [CGRect] = []
    func onAppear(image: UIImage) {
        self.image = image
        let correctedImage = scaleAndOrient(image: image)
        print(correctedImage.description) // "<UIImage:0x600003e0c240 anonymous {640, 394}>"
        // Transform image to fit screen.
        guard let cgImage = correctedImage.cgImage else {
            print("Trying to show an image not backed by CGImage!")
            return
        }

        let fullImageWidth = CGFloat(cgImage.width)
        let fullImageHeight = CGFloat(cgImage.height)

        let rate = fullImageWidth / UIScreen.main.bounds.width
        let imageFrame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: fullImageHeight / rate)
        let widthRatio = fullImageWidth / imageFrame.width
        let heightRatio = fullImageHeight / imageFrame.height

        // ScaleAspectFit: The image will be scaled down according to the stricter dimension.
        let scaleDownRatio = max(widthRatio, heightRatio)

        imageViewFrame = imageFrame
        // Cache image dimensions to reference when drawing CALayer paths.
//        imageWidth = fullImageWidth / scaleDownRatio
//        imageHeight = fullImageHeight / scaleDownRatio

        print(cgImage)
        let cgOrientation = CGImagePropertyOrientation(image.imageOrientation)
        performVisionRequest(image: cgImage, orientation: cgOrientation)

    }

    func performVisionRequest(image: CGImage, orientation: CGImagePropertyOrientation) {
        let imageRequestHandler = VNImageRequestHandler(cgImage: image,
                                                        orientation: orientation,
                                                        options: [:])

        let requests = [faceDetectionRequest]
        // Send the requests to the request handler.
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try imageRequestHandler.perform(requests)
            } catch let error as NSError {
                print("Failed to perform image request: \(error)")
                return
            }
        }
    }

    func updateImageViewFrame(with rect: CGRect) {
        imageViewFrame = rect
    }

    private func scaleAndOrient(image: UIImage) -> UIImage {
        // Set a default value for limiting image size.
        let maxResolution: CGFloat = UIScreen.main.bounds.width

        guard let cgImage = image.cgImage else {
            print("UIImage has no CGImage backing it!")
            return image
        }

        // Compute parameters for transform.
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        var transform = CGAffineTransform.identity

        var bounds = CGRect(x: 0, y: 0, width: width, height: height)

        if width > maxResolution ||
            height > maxResolution {
            let ratio = width / height
            if width > height {
                bounds.size.width = maxResolution
                bounds.size.height = round(maxResolution / ratio)
            } else {
                bounds.size.width = round(maxResolution * ratio)
                bounds.size.height = maxResolution
            }
        }

        let scaleRatio = bounds.size.width / width
        let orientation = image.imageOrientation
        switch orientation {
        case .up:
            transform = .identity
        case .down:
            transform = CGAffineTransform(translationX: width, y: height).rotated(by: .pi)
        case .left:
            let boundsHeight = bounds.size.height
            bounds.size.height = bounds.size.width
            bounds.size.width = boundsHeight
            transform = CGAffineTransform(translationX: 0, y: width).rotated(by: 3.0 * .pi / 2.0)
        case .right:
            let boundsHeight = bounds.size.height
            bounds.size.height = bounds.size.width
            bounds.size.width = boundsHeight
            transform = CGAffineTransform(translationX: height, y: 0).rotated(by: .pi / 2.0)
        case .upMirrored:
            transform = CGAffineTransform(translationX: width, y: 0).scaledBy(x: -1, y: 1)
        case .downMirrored:
            transform = CGAffineTransform(translationX: 0, y: height).scaledBy(x: 1, y: -1)
        case .leftMirrored:
            let boundsHeight = bounds.size.height
            bounds.size.height = bounds.size.width
            bounds.size.width = boundsHeight
            transform = CGAffineTransform(translationX: height, y: width).scaledBy(x: -1, y: 1).rotated(by: 3.0 * .pi / 2.0)
        case .rightMirrored:
            let boundsHeight = bounds.size.height
            bounds.size.height = bounds.size.width
            bounds.size.width = boundsHeight
            transform = CGAffineTransform(scaleX: -1, y: 1).rotated(by: .pi / 2.0)
        @unknown default:
                fatalError()
        }

        return UIGraphicsImageRenderer(size: bounds.size).image { rendererContext in
            let context = rendererContext.cgContext

            if orientation == .right || orientation == .left {
                context.scaleBy(x: -scaleRatio, y: scaleRatio)
                context.translateBy(x: -height, y: 0)
            } else {
                context.scaleBy(x: scaleRatio, y: -scaleRatio)
                context.translateBy(x: 0, y: -height)
            }
            context.concatenate(transform)
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
    }

    lazy var faceDetectionRequest = VNDetectFaceRectanglesRequest(completionHandler: self.handleDetectedFaces)

    private func handleDetectedFaces(request: VNRequest?, error: Error?) {
        if let nsError = error as NSError? {
            //self.presentAlert("Face Detection Error", error: nsError)
            return
        }
        // Perform drawing on the main thread.
        DispatchQueue.main.async {
            guard let results = request?.results as? [VNFaceObservation] else {
                    return
            }
            for observation in results {
                // withinImageBound => pathLayer.bound
                let rectBox = self.boundingBox(forRegionOfInterest: observation.boundingBox, withinImageBounds: self.imageViewFrame)
                print("detected Rect: \(rectBox.debugDescription)")
                self.detectedFrame.append(rectBox)
            }
//            self.draw(faces: results, onImageWithBounds: drawLayer.bounds)
//            drawLayer.setNeedsDisplay()
        }
    }

    fileprivate func boundingBox(forRegionOfInterest: CGRect, withinImageBounds bounds: CGRect) -> CGRect {

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

// Convert UIImageOrientation to CGImageOrientation for use in Vision analysis.
extension CGImagePropertyOrientation {
    init(_ uiImageOrientation: UIImage.Orientation) {
        switch uiImageOrientation {
            case .up: self = .up
            case .down: self = .down
            case .left: self = .left
            case .right: self = .right
            case .upMirrored: self = .upMirrored
            case .downMirrored: self = .downMirrored
            case .leftMirrored: self = .leftMirrored
            case .rightMirrored: self = .rightMirrored
            @unknown default:
                fatalError()
        }
    }
}
