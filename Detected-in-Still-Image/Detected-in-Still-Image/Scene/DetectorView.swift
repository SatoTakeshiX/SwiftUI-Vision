//
//  DetectorView.swift
//  Detected-in-Still-Image
//
//  Created by satoutakeshi on 2021/06/15.
//

import SwiftUI

public struct DetectorView: View {
    let image: UIImage
    let detectType: VisionRequestTypes.Set
    @StateObject var viewModel = DetectorViewModel()

    init(image: UIImage, requestType: VisionRequestTypes.Set) {
        self.image = image
        self.detectType = requestType
    }

    public var body: some View {
        VStack {
            Image(uiImage: viewModel.image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .opacity(0.6)
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
                    .stroke(Color.blue, lineWidth: 1)
                    .scaleEffect(x: 1.0, y: -1.0, anchor: .center)
                )
            DetectedInfomationView(info: viewModel.detectedInfo)
        }
        .onAppear {
            viewModel.onAppear(image: image, detectType: detectType)
        }
    }
}

struct DetectedInfomationView: View {
    let info: [[String: String]]

    var body: some View {
        List {
            ForEach(info.indices, id: \.self) { index in
                Section(header: Text("index \(index)")) {
                    ForEach(Array(info[index].keys), id: \.self) { key in
                        HStack {
                            Text("\(key)")
                            Spacer()
                            Text("\(info[index][key] ?? "")")
                        }
                    }
                }
            }
        }
    }
}

struct DetectorView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            DetectorView(image: UIImage(named: "IMG_4987")!, requestType: [.all])
        }
    }
}
