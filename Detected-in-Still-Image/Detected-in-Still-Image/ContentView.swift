//
//  ContentView.swift
//  Detected-in-Still-Image
//
//  Created by satoutakeshi on 2021/06/15.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationView {
            Form {
                List {
                    NavigationLink("Face Rect", destination: DetectorView(image: UIImage(named: "people")!, requestType: [.faceRect]))
                }
                List {
                    NavigationLink("Face Landmarks", destination: DetectorView(image: UIImage(named: "ParentChild")!, requestType: [.faceLandmarks]))
                }
                List {
                    NavigationLink("Text", destination: DetectorView(image: UIImage(named: "swiftui_recipe")!, requestType: [.text]))
                }
                List {
                    NavigationLink("Text Recognize", destination: DetectorView(image: UIImage(named: "wikipedia_computer_vision")!, requestType: [.textRecognize]))
                }
                List {
                    NavigationLink("barcode", destination: DetectorView(image: UIImage(named: "qr_code")!, requestType: [.barcode]))
                }
                List {
                    NavigationLink("Rect", destination: DetectorView(image: UIImage(named: "book_keyboard")!, requestType: [.rect]))
                }
            }
            .navigationTitle("Still Image Detector")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
