//
//  CustomLayerView.swift
//  Realtime-Face-Tracking
//
//  Created by satoutakeshi on 2021/05/31.
//

import SwiftUI
/// UIViewRepresentableを使うとview.frameがzeroになりlayerが描画されない。
/// UIViewControllerRepresentableを利用するとviewController.viewは端末サイズが与えられる
struct CustomLayerView: UIViewControllerRepresentable {
    typealias UIViewControllerType = UIViewController
    var layer: CALayer

    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()
        viewController.view.layer.addSublayer(layer)
        layer.frame = viewController.view.layer.frame
        return viewController
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        layer.frame = uiViewController.view.layer.frame
    }
}

struct CustomLayerView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            CustomLayerView(layer: mockLayer)
                .background(Color.clear)
                .previewLayout(.fixed(width: 50, height: 50))
        }
    }

    static var mockLayer: CALayer {
        let layer = CALayer()
        layer.backgroundColor = UIColor.green.cgColor
        return layer
    }
}
