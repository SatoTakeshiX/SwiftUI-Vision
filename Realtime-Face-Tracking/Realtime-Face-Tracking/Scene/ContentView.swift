//
//  ContentView.swift
//  Realtime-Face-Tracking
//
//  Created by satoutakeshi on 2021/05/31.
//

import SwiftUI

struct ContentView: View {
    @StateObject var session = CaptureSession() // initでsessionを作成しないとpreviewで表示されない
    var body: some View {
        #if targetEnvironment(simulator)
        Text("please run a real device")
        #else
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            Text("running in preview")
        } else {
            ZStack {
                CustomLayerView(layer: session.previewLayer ?? CALayer())
            }
            .edgesIgnoringSafeArea(.all)
            .onAppear {
                session.startSettion()
            }
        }
        #endif
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
