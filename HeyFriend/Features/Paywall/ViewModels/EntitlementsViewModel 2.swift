//
//  EntitlementsViewModel 2.swift
//  HeyFriend
//
//  Created by Denis Tatar 2 on 9/8/25.
//


import SwiftUI
import FirebaseAuth

final class EntitlementsViewModel: ObservableObject {
    @Published private(set) var plan: String = "free"
    @Published private(set) var freeUsed: Int = 0
    @Published private(set) var freeLimit: Int = 4
    @Published private(set) var isLoaded = false
    
    private var listener: ListenerRegistration?
    
    func start() {
        guard let uid = AuthService.shared.userId else { return }
        Task {
            try? await FirestoreService.shared.ensureEntitlements(uid: uid)
            self.listener = FirestoreService.shared.observeEntitlements(uid: uid) { [weak self] dto in
                guard let self, let dto else { return }
                self.plan = dto.plan
                self.freeUsed = dto.freeSessionsUsed
                self.freeLimit = dto.freeLimit
                self.isLoaded = true
            }
        }
    }
    
    func stop() {
        listener?.remove()
    }
    
    var remaining: Int { max(freeLimit - freeUsed, 0) }
    var isPlus: Bool { plan == "plus" }
}
