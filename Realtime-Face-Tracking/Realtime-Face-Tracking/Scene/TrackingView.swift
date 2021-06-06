//
//  ContentView.swift
//  Realtime-Face-Tracking
//
//  Created by satoutakeshi on 2021/05/31.
//

import SwiftUI

struct TrackingView: View {
    @StateObject var viewModel = TrackingViewModel() // initでsessionを作成しないとpreviewで表示されない
    var closePath: Bool = true
    var body: some View {
        #if targetEnvironment(simulator)
        Text("please run on real device")
        #else
        ZStack {
            CustomLayerView(layer: viewModel.previewLayer)

            Path { path in
                path.addRect(viewModel.output?.faceRect ?? .zero)
            }
            .applying(.identity)
            .stroke()
            .fill(Color.red)
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
