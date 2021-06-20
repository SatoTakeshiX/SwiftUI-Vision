//
//  VisionClient.swift
//  Detected-in-Still-Image
//
//  Created by satoutakeshi on 2021/06/20.
//

import Foundation
import Vision

enum VisionRequestTypes {
    case faceRect
    case faceLandmarks
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

    @Published var requestTypes: VisionRequestTypes.Set
    init(requests: VisionRequestTypes.Set) {
        self.requestTypes = requests
    }
}
