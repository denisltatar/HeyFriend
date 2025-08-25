//
//  SessionsHomeView.swift
//  HeyFriend
//
//  Created by Denis Tatar 2 on 8/19/25.
//

import Foundation
import SwiftUI

struct SessionsHomeView: View {
    @State private var goToChat = false
    @State private var isPressed = false

    var body: some View {
        VStack(spacing: 24) {
            Text("Talk it out whenever you’re ready.")
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Start button
            Button {
                goToChat = true
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "mic.fill")
                        .foregroundStyle(.white)
                    Text("Start Session")
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 1.00, green: 0.72, blue: 0.34), // amber
                                Color(red: 1.00, green: 0.45, blue: 0.00)  // orange
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    )
                    .shadow(color: Color(red: 1.00, green: 0.65, blue: 0.20).opacity(0.35),
                            radius: 10, x: 0, y: 6)
            }
            .buttonStyle(.plain)
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.12), value: isPressed)
            .simultaneousGesture(DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
            )
            .padding(.horizontal)

            Spacer()
        }
        .navigationTitle("Sessions")
        // Programmatic navigation
        .background(
            NavigationLink(
                destination: ChatView()
//                    .navigationTitle("Live Session")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar(.hidden, for: .tabBar),
                isActive: $goToChat,
                label: { EmptyView() }
            )
            .hidden()
        )
        
        // Replace the NavigationLink background with:
//        .fullScreenCover(isPresented: $showChat) {
//            NavigationStack {
//                ChatView()
//                    .navigationTitle("Live Session")
//                    .navigationBarTitleDisplayMode(.inline)
//                    .toolbar {
//                        ToolbarItem(placement: .topBarLeading) {
//                            Button(role: .cancel) { showChat = false } label: {
//                                Label("End", systemImage: "xmark.circle.fill")
//                            }
//                        }
//                    }
//                    .interactiveDismissDisabled(true) // prevent swipe-to-dismiss
//            }
//        }
        
        
    }
}
