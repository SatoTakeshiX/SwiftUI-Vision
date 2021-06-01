//
//  TrackingViewModel.swift
//  Realtime-Face-Tracking
//
//  Created by satoutakeshi on 2021/06/02.
//

import Combine
import UIKit

final class TrackingViewModel: ObservableObject {
    let captureSession = CaptureSession()

    var previewLayer: CALayer {
        return captureSession.previewLayer
    }
    
    private var cancellables: Set<AnyCancellable> = []

    func startSession() {
        captureSession.startSettion()
        captureSession.outputs.sink { output in
            print(output)
        }.store(in: &cancellables)
    }
}
