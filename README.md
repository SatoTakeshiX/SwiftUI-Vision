# SwiftUI-Vision

VisionフレームワークをSwiftUIで実装したサンプルアプリ

## Detected-in-Still-Image

静的画像をVisionで画像解析します。

### 対応しているRequest

* VNDetectFaceRectanglesRequest
  * 顔の矩形を検知
* VNDetectFaceLandmarksRequest
  * 顔の特長点を検知
* VNDetectTextRectanglesRequest
  * テキストの矩形を検知
  * 単語の矩形と一文字づつの矩形を検知
* VNRecognizeTextRequest
  * テキストを認識
* VNDetectBarcodesRequest
  * バーコードの矩形を検知
  * バーコードの内容を認識
* VNDetectRectanglesRequest 
  * 矩形の形のものを検知

## Realtime-Face-Tracking

カメラフレームからリアルタイムで顔を検知します。

TBD

