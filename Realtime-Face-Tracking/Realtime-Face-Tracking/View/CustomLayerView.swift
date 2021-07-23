//
//  CustomLayerView.swift
//  Realtime-Face-Tracking
//
//  Created by satoutakeshi on 2021/05/31.
//

import SwiftUI
import Vision
import AVFoundation
/// UIViewRepresentableを使うとview.frameがzeroになりlayerが描画されない。
/// UIViewControllerRepresentableを利用するとviewController.viewは端末サイズが与えられる
struct CustomLayerView: UIViewControllerRepresentable {
    typealias UIViewControllerType = UIViewController
    var previewLayer: AVCaptureVideoPreviewLayer
    @Binding var objectObservations: [VNDetectedObjectObservation]
    @Binding var pixelSize: CGSize

    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()
        viewController.view.layer.addSublayer(previewLayer)
        previewLayer.frame = viewController.view.layer.frame
        return viewController
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        previewLayer.frame = uiViewController.view.layer.frame
        drawFaceObservations(objectObservations)
    }

    private func radiansForDegrees(_ degrees: CGFloat) -> CGFloat {
        return CGFloat(Double(degrees) * Double.pi / 180.0)
    }

    func drawFaceObservations(_ observations: [VNDetectedObjectObservation]) {
        previewLayer.sublayers?.removeSubrange(1...)
        let captureDeviceResolution = self.pixelSize

        let captureDeviceBounds = CGRect(x: 0,
                                         y: 0,
                                         width: captureDeviceResolution.width,
                                         height: captureDeviceResolution.height)

        let captureDeviceBoundsCenterPoint = CGPoint(x: captureDeviceBounds.midX,
                                                     y: captureDeviceBounds.midY)

        let normalizedCenterPoint = CGPoint(x: 0.5, y: 0.5)
        let overlayLayer = CALayer()
        overlayLayer.name = "DetectionOverlay"
        overlayLayer.masksToBounds = true
        overlayLayer.anchorPoint = normalizedCenterPoint
        overlayLayer.bounds = captureDeviceBounds
        overlayLayer.position = captureDeviceBoundsCenterPoint//CGPoint(x: previewLayer.bounds.midX, y: previewLayer.bounds.midY)
        overlayLayer.borderColor = UIColor.blue.cgColor
        overlayLayer.borderWidth = 4

        let videoPreviewRect = previewLayer.layerRectConverted(fromMetadataOutputRect: CGRect(x: 0, y: 0, width: 1, height: 1))
        var rotation: CGFloat
        var scaleX: CGFloat
        var scaleY: CGFloat

        // Rotate the layer into screen orientation.
        switch UIDevice.current.orientation {
        case .portraitUpsideDown:
            rotation = 180
            scaleX = videoPreviewRect.width / captureDeviceResolution.width
            scaleY = videoPreviewRect.height / captureDeviceResolution.height

        case .landscapeLeft:
            rotation = 90
            scaleX = videoPreviewRect.height / captureDeviceResolution.width
            scaleY = scaleX

        case .landscapeRight:
            rotation = -90
            scaleX = videoPreviewRect.height / captureDeviceResolution.width
            scaleY = scaleX

        default:
            rotation = 0
            scaleX = videoPreviewRect.width / captureDeviceResolution.width
            scaleY = videoPreviewRect.height / captureDeviceResolution.height
        }

        // Scale and mirror the image to ensure upright presentation.
        let affineTransform = CGAffineTransform(rotationAngle: radiansForDegrees(rotation))
            .scaledBy(x: scaleX, y: -scaleY)
        overlayLayer.setAffineTransform(affineTransform)
        overlayLayer.position = CGPoint(x: previewLayer.bounds.midX, y: previewLayer.bounds.midY)

        previewLayer.addSublayer(overlayLayer)

        guard let observation = objectObservations.first else { return }
        let xMin = observation.boundingBox.minX
        let yMax = observation.boundingBox.maxY

        var xCoord = xMin * overlayLayer.frame.size.width
        let yCoord = (1 - yMax) * overlayLayer.frame.size.height // これがどういうことだったかをもう一度理解する
        let width = observation.boundingBox.width * overlayLayer.frame.size.width
        let height = observation.boundingBox.height * overlayLayer.frame.size.height

        let subfromCenter = xCoord - overlayLayer.frame.midX
        let mirrerdMaxX = overlayLayer.frame.midX - subfromCenter
        xCoord = mirrerdMaxX - width

        let layer = CALayer()
        layer.frame = CGRect(x: xMin * overlayLayer.frame.size.width + overlayLayer.frame.minX, y: yCoord, width: width, height: height)
        layer.borderWidth = 2.0
        layer.borderColor = UIColor.green.cgColor

        previewLayer.addSublayer(layer)
    }
}
//
//struct CustomLayerView_Previews: PreviewProvider {
//    static var previews: some View {
//        Group {
//            CustomLayerView(previewLayer: mockLayer, faceObservation: [])
//                .background(Color.clear)
//                .previewLayout(.fixed(width: 50, height: 50))
//        }
//    }
//
//    static var mockLayer: AVCaptureVideoPreviewLayer {
//        let layer = CALayer()
//        layer.backgroundColor = UIColor.green.cgColor
//        return layer
//    }
//}
