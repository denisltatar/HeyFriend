//
//  ChatView.swift
//  HeyFriend
//
//  Created by Denis Tatar 2 on 8/8/25.
//

import Foundation
import SwiftUI

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var voiceRepliesOn = true

    var body: some View {
        VStack(spacing: 20) {
            ScrollView {
                Text(viewModel.transcribedText)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                if !viewModel.aiResponse.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Divider()
                        Text("HeyFriend says:")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(viewModel.aiResponse)
                            .font(.body)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                }

            }

            Button(action: {
                viewModel.toggleRecording()
            }) {
                Image(systemName: viewModel.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                    .resizable()
                    .frame(width: 100, height: 100)
                    .foregroundColor(viewModel.isRecording ? .red : .accentColor)
            }

            Text(viewModel.isRecording ? "Listening..." : "Tap to talk")
                .font(.footnote)
                .foregroundColor(.gray)
        }
        .padding()
        .navigationTitle("Chat")
    }
}
