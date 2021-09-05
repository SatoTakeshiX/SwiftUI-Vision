# SwiftUI-Vision

VisionフレームワークをSwiftUIで実装したサンプルアプリ

## Detected-in-Still-Image

![chapter3_01](https://user-images.githubusercontent.com/4253490/132113953-e689f6cb-fd24-492c-9ca7-17bbabf9fbaa.png)


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

![chapter4_01](https://user-images.githubusercontent.com/4253490/132113966-058f7ace-5de1-4d21-bbd1-dcf5e4aca218.png)

* VNTrackObjectRequest
   * 連続するフレーム画像で物体を追跡するリクエスト

