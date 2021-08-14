//
//  ContentView.swift
//  SwiftUIOverview
//
//  Created by satoutakeshi on 2021/07/16.
//

import SwiftUI
import Combine

struct ContentView: View {
    @StateObject var viewModel = ContentViewModel()
    var body: some View {
        VStack {
            Image("people")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .opacity(0.6)
                .overlay(
                    // for retrieve image frame
                    GeometryReader { proxy -> AnyView in
                        viewModel.input(imageFrame: proxy.frame(in: .local))
                        return AnyView(EmptyView())
                    }
                )
            Text(viewModel.imageFrameLabel)
            GeometryReader { proxy in
                Text("\(proxy.frame(in: .global).debugDescription)")
            }
            Image("people")
                .opacity(0.6)
                .overlay(
                    Path { path in
                        path.addRect(CGRect(x: 10, y: 10, width: 50, height: 50))
                    }
                    .stroke(Color.red)
                )
            Path { path in
                path.addRect(CGRect(x: 10, y: 10, width: 100, height: 100))
            }
            .stroke(Color.red, lineWidth: 2)
            Path { path in
                path.addLines([CGPoint(x: 0, y: 0),
                               CGPoint(x: 100, y: 100)])
            }
            .stroke(Color.red, lineWidth: 2)
        }
        .onAppear {
            // do something
        }
    }
}

final class ContentViewModel: ObservableObject {
    @Published var imageFrameLabel: String = ""
    // private var imageViewFramePublisher = PassthroughSubject<CGRect, Never>()
    private var subscriber: Set<AnyCancellable> = []
    init() {
        $imageFrameLabel.removeDuplicates()
            .map { rect in
                rect.debugDescription
            }
            .assign(to: &$imageFrameLabel)
    }
    func input(imageFrame: CGRect) {
        print(imageFrame.debugDescription)
        imageFrameLabel = imageFrame.debugDescription
        //imageViewFramePublisher.send(imageFrame)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
