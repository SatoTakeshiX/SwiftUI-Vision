//
//  ContentView.swift
//  Realtime-Face-Tracking
//
//  Created by satoutakeshi on 2021/05/31.
//

import SwiftUI

struct TrackingView: View {
    @StateObject var viewModel = TrackingViewModel()
    var closePath: Bool = true
    var body: some View {
        #if targetEnvironment(simulator)
        Text("please run on real device")
        #else
        ZStack {
            CustomLayerView(previewLayer: viewModel.previewLayer, faceObservations: $viewModel.faceObservation, pixelSize: $viewModel.pixelSize)
        }
        .edgesIgnoringSafeArea(.all)
        .onAppear {
            viewModel.startSession()
        }
        #endif
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        TrackingView()
    }
}
