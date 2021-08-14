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
                    // 画像Viewの座標情報を取得
                    GeometryReader { proxy -> AnyView in
                        viewModel.input(imageFrame: proxy.frame(in: .local))
                        return AnyView(EmptyView())
                    }
                )
                .overlay(
                    Path { path in
                        for frame in viewModel.detectedFrame {
                            path.addRect(frame)
                        }
                    }
                    .stroke(Color.green, lineWidth: 2.0)
                    .scaleEffect(x: 1.0, y: -1.0, anchor: .center)
                )
                .overlay(
                    Path { path in
                        for (closed, points) in viewModel.detectedPoints {
                            path.addLines(points)
                            if closed {
                                // パスを閉じる
                                path.closeSubpath()
                            }
                        }
                    }
                    .stroke(Color.blue, lineWidth: 2.0)
                    .scaleEffect(x: 1.0, y: -1.0, anchor: .center)
                )
            DetectedInfomationView(info: viewModel.detectedInfo)
        }
        .onAppear {
            // 画像情報と検出タイプをViewModelに渡す
            viewModel.onAppear(image: image, detectType: detectType)
        }
    }

    private func detectViewRect(geo: GeometryProxy) -> AnyView {

        print(geo.frame(in: .local).debugDescription)
        return AnyView(EmptyView())
    }
}

struct DetectedInfomationView: View {
    let info: [[String: String]]

    var body: some View {
        List {
            ForEach(info.indices, id: \.self) { index in
                Section(header: Text("index \(index)")) {
                    ForEach(Array(info[index].keys.sorted()), id: \.self) { key in
                        HStack {
                            Text("\(key)")
                            Spacer()
                            Text("\(info[index][key] ?? "")")
                                .fixedSize(horizontal: false, vertical: true)
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
            DetectorView(image: UIImage(named: "people")!, requestType: [.all])
        }
    }
}
