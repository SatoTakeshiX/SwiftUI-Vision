//
//  ContentView.swift
//  Detected-in-Still-Image
//
//  Created by satoutakeshi on 2021/06/15.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            DetectorView(image: UIImage(named: "people")!) {
//                Text("ssss")
//                    .foregroundColor(.blue)
//                    .border(Color.green, width: /*@START_MENU_TOKEN@*/1/*@END_MENU_TOKEN@*/)
            }
            List {
                Text("sss")
                Text("ddd")
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
