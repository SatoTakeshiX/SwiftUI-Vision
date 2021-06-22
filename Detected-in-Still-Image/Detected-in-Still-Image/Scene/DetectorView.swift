//
//  DetectorView.swift
//  Detected-in-Still-Image
//
//  Created by satoutakeshi on 2021/06/15.
//

import SwiftUI

public struct DetectorView<Content>: View where Content: View {
    let image: UIImage
    let detectType: VisionRequestTypes.Set
    let builder: () -> Content
    @StateObject var viewModel = DetectorViewModel()

    init(image: UIImage, requestType: VisionRequestTypes.Set, @ViewBuilder builder: @escaping () -> Content) {
        self.builder = builder
        self.image = image
        self.detectType = requestType
    }

    public var body: some View {
        ZStack {
            Image(uiImage: viewModel.image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .border(Color.red, width: 1)
                .overlay(
                    Path { path in
                        for frame in viewModel.detectedFrame {
                            path.addRect(frame)
                        }
                    }
                    .stroke(Color.blue, lineWidth: 2.0)
                    .scaleEffect(x: 1.0, y: -1.0, anchor: .center)
                )
                .overlay(
                    Path { path in
                        for element in viewModel.detectedFaceLandmarkPoints {
                            for (closed, points) in element {
                                path.addLines(points)
                                if closed {
                                    path.closeSubpath()
                                }
                            }
                        }
                    }
                    .stroke(Color.black, lineWidth: 1)
                    .scaleEffect(x: 1.0, y: -1.0, anchor: .center)
                )
            builder()
        }
        .onAppear {
            viewModel.onAppear(image: image, detectType: detectType)
        }
    }
}

struct DetectorView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            DetectorView(image: UIImage(named: "people")!, requestType: [.all]) {
                Text("ssss")
                    .foregroundColor(.blue)
                    .border(Color.green, width: /*@START_MENU_TOKEN@*/1/*@END_MENU_TOKEN@*/)
            }
            List {
                Text("sss")
                Text("ddd")
            }
        }

    }
}
