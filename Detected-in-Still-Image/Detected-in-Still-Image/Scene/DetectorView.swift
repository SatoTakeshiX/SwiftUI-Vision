//
//  DetectorView.swift
//  Detected-in-Still-Image
//
//  Created by satoutakeshi on 2021/06/15.
//

import SwiftUI

public struct DetectorView<Content>: View where Content: View {
    let builder: () -> Content
    let image: UIImage
    init(image: UIImage, @ViewBuilder builder: @escaping () -> Content) {
        self.builder = builder
        self.image = image
    }

    public var body: some View {
        ZStack {
            GeometryReader { geo in
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                VStack {
                    Text("global: \(geo.frame(in: .global).debugDescription)")
                        .foregroundColor(.white)
                        .font(.title)
                    Text("local: \(geo.frame(in: .local).debugDescription)")
                        .foregroundColor(.white)
                        .font(.title)
                }

                builder()
            }

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
