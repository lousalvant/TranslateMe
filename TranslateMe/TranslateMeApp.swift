//
//  TranslateMeApp.swift
//  TranslateMe
//
//  Created by Lou-Michael Salvant on 10/20/24.
//

import SwiftUI
import FirebaseCore

@main
struct TranslateMeApp: App {

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            TranslationView()
        }
    }
}
