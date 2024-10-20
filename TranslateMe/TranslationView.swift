//
//  TranslationView.swift
//  TranslateMe
//
//  Created by Lou-Michael Salvant on 10/20/24.
//

import SwiftUI
import FirebaseFirestore

struct TranslationView: View {
    @State private var textToTranslate: String = ""
    @State private var translatedText: String = ""
    @ObservedObject var translationManager = TranslationManager()

    var body: some View {
        VStack {
            TextField("Enter text to translate", text: $textToTranslate)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            Button("Translate") {
                translateText()
            }
            .padding()

            Text(translatedText)
                .padding()

            List(translationManager.history, id: \.self) { historyItem in
                Text(historyItem)
            }

            Button("Clear History") {
                translationManager.clearHistory()
            }
            .padding()
        }
        .onAppear {
            translationManager.loadHistory() // Load history on app start
        }
        .padding()
    }

    func translateText() {
        let encodedText = textToTranslate.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let apiUrl = "https://api.mymemory.translated.net/get?q=\(encodedText)&langpair=en|es"

        guard let url = URL(string: apiUrl) else { return }

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Translation error: \(error.localizedDescription)")
                return
            }

            if let data = data, let jsonResponse = try? JSONDecoder().decode(MyMemoryResponse.self, from: data) {
                DispatchQueue.main.async {
                    translatedText = jsonResponse.responseData.translatedText
                    translationManager.saveTranslation(original: textToTranslate, translated: translatedText)
                }
            } else {
                print("Failed to decode translation response.")
            }
        }.resume()
    }
}

struct MyMemoryResponse: Codable {
    let responseData: TranslationData
}

struct TranslationData: Codable {
    let translatedText: String
}

#Preview {
    TranslationView()
}
