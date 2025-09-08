//
//  EntitlementsViewModel.swift
//  HeyFriend
//
//  Created by Denis Tatar 2 on 9/8/25.
//

import Foundation
import SwiftUI
import Combine
import FirebaseAuth
import FirebaseFirestore

final class EntitlementsViewModel: ObservableObject {
    @Published private(set) var plan: String = "free"
    @Published private(set) var freeUsed: Int = 0
    @Published private(set) var freeLimit: Int = 4
    @Published private(set) var isLoaded = false
    
    private var listener: ListenerRegistration?
    private var cancellables = Set<AnyCancellable>()
    
    func start() {
        // 1) React to auth changes
        AuthService.shared.$userId
            .removeDuplicates()
            .sink { [weak self] uid in
                guard let self else { return }
                self.attach(uid: uid)
            }
            .store(in: &cancellables)
        
        // Also handle the current state immediately
        attach(uid: AuthService.shared.userId)
    }
    
    func stop() {
        listener?.remove()
        listener = nil
        cancellables.removeAll()
    }
    
    private func attach(uid: String?) {
        // Tear down old listener
        listener?.remove()
        listener = nil
        isLoaded = false
        
        guard let uid else { return }
        
        Task { @MainActor in
            // 2) Ensure doc exists
            try? await FirestoreService.shared.ensureEntitlements(uid: uid)
            
            // 3) Observe changes
            listener = FirestoreService.shared.observeEntitlements(uid: uid) { [weak self] dto in
                guard let self, let dto else { return }
                DispatchQueue.main.async {
                    self.plan = dto.plan
                    self.freeUsed = dto.freeSessionsUsed
                    self.freeLimit = dto.freeLimit
                    self.isLoaded = true
                }
            }
        }
    }
    
    var remaining: Int { max(freeLimit - freeUsed, 0) }
    var isPlus: Bool { plan == "plus" }
}
