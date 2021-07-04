//
//  Realtime_Face_TrackingTests.swift
//  Realtime-Face-TrackingTests
//
//  Created by satoutakeshi on 2021/05/31.
//

import XCTest

class MockDataTests: XCTestCase {
    func testPixelBufferCreate() throws {
        guard let blackImage = UIImage.colorImage(color: UIColor.black, size: .init(width: 10, height: 10)) else { return }
        let pixelBuffer = MockData.getCVPixelBuffer(blackImage.cgImage!)
        XCTAssertNotNil(pixelBuffer)
    }
}
