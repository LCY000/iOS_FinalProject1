//
//  Final_ProjectApp.swift
//  Final Project
//
//  Created by ChengYou on 2026/3/23.
//

import OSLog
import SwiftUI

@main
struct Final_ProjectApp: App {
    init() {
        Logger.session.debug("Final_ProjectApp init")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    Logger.session.debug("ContentView appeared")
                }
        }
    }
}
