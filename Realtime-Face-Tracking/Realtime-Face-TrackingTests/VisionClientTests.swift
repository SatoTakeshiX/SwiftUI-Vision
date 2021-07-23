//
//  VisionClientTests.swift
//  Realtime-Face-TrackingTests
//
//  Created by satoutakeshi on 2021/07/04.
//

import XCTest
@testable import Realtime_Face_Tracking
import UIKit

class VisionClientTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testRequest() throws {
        let resultExpectation = expectation(description: "resultExpectation")
        let visionClient = VisionClient(mode: .tracking)
        visionClient.$visionFaceResults.sink { rect in
            resultExpectation.fulfill()
        }

        let image = UIImage(named: "people", in: Bundle(for: VisionClientTests.self), with: nil)
        XCTAssertNotNil(image)
        guard let image = image, let cgImage = image.cgImage else {
            XCTFail()
            return
        }

        guard let pixelBuffer = MockData.getCVPixelBuffer(cgImage) else {
            XCTFail()
            return
        }
        visionClient.request(cvPixelBuffer: pixelBuffer, orientation: .up)
        wait(for: [resultExpectation], timeout: 3)
    }

    func testChangeState() throws {
        let faceExpectation = expectation(description: "faceExpectation")
        let trackingExpectation = expectation(description: "trackingExpectation")
        let visionClient = VisionClient(mode: .tracking)
        XCTAssertEqual(visionClient.state, .stop)
        visionClient.$state.sink { state in
            switch state {
                case .stop:
                    break
                case .detectedFace:
                    faceExpectation.fulfill()
                case .tracking:
                trackingExpectation.fulfill()
            }

        }

        let image = UIImage(named: "people", in: Bundle(for: VisionClientTests.self), with: nil)
        XCTAssertNotNil(image)
        guard let image = image, let cgImage = image.cgImage else {
            XCTFail()
            return
        }

        guard let pixelBuffer = MockData.getCVPixelBuffer(cgImage) else {
            XCTFail()
            return
        }

        visionClient.request(cvPixelBuffer: pixelBuffer, orientation: .up)
        visionClient.request(cvPixelBuffer: pixelBuffer, orientation: .up)
        visionClient.request(cvPixelBuffer: pixelBuffer, orientation: .up)

        wait(for: [faceExpectation, trackingExpectation], timeout: 3)

    }
}
