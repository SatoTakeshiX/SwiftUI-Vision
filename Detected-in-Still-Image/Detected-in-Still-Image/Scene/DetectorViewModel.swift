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
import Combine

final class DetectorViewModel: ObservableObject {

    @Published var image: UIImage = UIImage()
    @Published var detectedFrame: [CGRect] = []
    @Published var detectedFaceLandmarkPoints: [[Bool: [CGPoint]]] = []
    @Published var detectedInfo: [[String: String]] = []
    private var cancellables: Set<AnyCancellable> = []
    private var errorCancellables: Set<AnyCancellable> = []
    let visionClient = VisionClient()

    init() {
        visionClient.$result
            .receive(on: RunLoop.main)
            .sink { type in
                switch type {
                    case .faceLandmarks(let drawPoints, let info):
                        self.detectedFaceLandmarkPoints = drawPoints
                        self.detectedInfo.append(contentsOf: info)
                    case .faceRect(let rectBox, let info):
                        self.detectedFrame = rectBox
                        self.detectedInfo.append(contentsOf: info)
                    case .word(let rectBoxes, let info):
                        self.detectedFrame.append(contentsOf: rectBoxes)
                        self.detectedInfo.append(contentsOf: info)
                    case .character(let rectBox, let info):
                        self.detectedFrame.append(contentsOf: rectBox)
                        self.detectedInfo.append(contentsOf: info)
                    default:
                        break
                }
            }
            .store(in: &cancellables)

        visionClient.$error
            .receive(on: RunLoop.main)
            .sink { error in
                print(error?.localizedDescription ?? "")
            }
            .store(in: &errorCancellables)
    }

    func onAppear(image: UIImage, detectType: VisionRequestTypes.Set) {
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

        visionClient.configure(type: detectType, imageViewFrame: imageFrame)

        print(cgImage)
        let cgOrientation = CGImagePropertyOrientation(image.imageOrientation)

        // clear info
        detectedInfo.removeAll()
        visionClient.performVisionRequest(image: cgImage, orientation: cgOrientation)
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
