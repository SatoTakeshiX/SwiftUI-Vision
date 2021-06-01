//
//  ContentView.swift
//  Realtime-Face-Tracking
//
//  Created by satoutakeshi on 2021/05/31.
//

import SwiftUI

struct TrackingView: View {
    @StateObject var session = CaptureSession() // initでsessionを作成しないとpreviewで表示されない
    var body: some View {
        #if targetEnvironment(simulator)
        Text("please run on real device")
        #else
        ZStack {
            CustomLayerView(layer: session.previewLayer ?? CALayer())
        }
        .edgesIgnoringSafeArea(.all)
        .onAppear {
            session.startSettion()
        }
        #endif
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        TrackingView()
    }
}
