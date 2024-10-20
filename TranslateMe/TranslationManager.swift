//
//  TranslationManager.swift
//  TranslateMe
//
//  Created by Lou-Michael Salvant on 10/20/24.
//

import FirebaseFirestore
import SwiftUI

class TranslationManager: ObservableObject {
    @Published var history: [String] = []
    private let db = Firestore.firestore()

    func saveTranslation(original: String, translated: String) {
        let historyItem = "\(original) -> \(translated)"
        
        // Save translation to Firestore
        db.collection("translations").addDocument(data: ["translation": historyItem]) { error in
            if let error = error {
                print("Error saving translation: \(error.localizedDescription)")
            } else {
                DispatchQueue.main.async {
                    self.history.append(historyItem) // Update UI with new translation
                }
            }
        }
    }

    func loadHistory() {
        // Fetch history from Firestore
        db.collection("translations").getDocuments { snapshot, error in
            if let error = error {
                print("Error fetching history: \(error.localizedDescription)")
                return
            }

            if let snapshot = snapshot {
                let fetchedHistory = snapshot.documents.compactMap { document in
                    document.data()["translation"] as? String
                }

                DispatchQueue.main.async {
                    self.history = fetchedHistory // Update UI with fetched history
                }
            }
        }
    }

    func clearHistory() {
        // Fetch all documents to delete
        db.collection("translations").getDocuments { snapshot, error in
            if let error = error {
                print("Error clearing history: \(error.localizedDescription)")
                return
            }

            snapshot?.documents.forEach { document in
                self.db.collection("translations").document(document.documentID).delete { error in
                    if let error = error {
                        print("Error deleting document: \(error.localizedDescription)")
                    }
                }
            }

            DispatchQueue.main.async {
                self.history.removeAll() // Clear history from UI
            }
        }
    }
}
