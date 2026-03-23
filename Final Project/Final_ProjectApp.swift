//
//  Final_ProjectApp.swift
//  Final Project
//
//  Created by ChengYou on 2026/3/23.
//

import SwiftUI

@main
struct Final_ProjectApp: App {
    init() {
        print("🟢 [App] Final_ProjectApp init")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    print("🟢 [App] ContentView appeared")
                }
        }
    }
}
