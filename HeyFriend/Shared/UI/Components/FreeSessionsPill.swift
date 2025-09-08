//
//  FreeSessionsPill.swift
//  HeyFriend
//
//  Created by Denis Tatar 2 on 9/8/25.
//

import Foundation
import SwiftUI

struct FreeSessionsPill: View {
    let isPlus: Bool
    let remaining: Int
    var onUpgradeTap: (() -> Void)?
    
    var body: some View {
        HStack {
            Image(systemName: isPlus ? "infinity" : "gift.fill")
            if isPlus {
                Text("Unlimited sessions")
            } else {
                Text("\(remaining) free left")
            }
            Spacer()
            if !isPlus {
                Button("Upgrade") { onUpgradeTap?() }
                    .font(.footnote.bold())
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
