//
//  DetectorView.swift
//  Detected-in-Still-Image
//
//  Created by satoutakeshi on 2021/06/15.
//

import SwiftUI

public struct DetectorView<Content>: View where Content: View {
    let image: UIImage
    let builder: () -> Content
    @StateObject var viewModel = DetectorViewModel()

    init(image: UIImage, @ViewBuilder builder: @escaping () -> Content) {
        self.builder = builder
        self.image = image
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
                        for points in viewModel.detectedFaceLandmarkPoints {
                            path.addLines(points)
                        }

                        path.closeSubpath()
                    }
                    //.applying(viewModel.landmarkAffineTransform)
                    //.transform(viewModel.landmarkAffineTransform)
                    .stroke(Color.black, lineWidth: 2)
                    .scaleEffect(x: 1.0, y: -1.0, anchor: .center)
                )
            builder()
        }
        .onAppear {
            viewModel.onAppear(image: image)
        }
    }

    func useProxy(_ proxy: GeometryProxy) -> some View {
        viewModel.updateImageViewFrame(with: proxy.frame(in: .global))
        return Group {
            Image(uiImage: viewModel.image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .border(Color.red, width: 1)
            VStack {
                Text("global: \(proxy.frame(in: .global).debugDescription)")
                    .foregroundColor(.white)
                    .font(.title)
            }
            builder()
        }
    }
}

struct DetectorView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            DetectorView(image: UIImage(named: "people")!) {
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
