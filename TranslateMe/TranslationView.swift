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

    // Default languages
    @State private var sourceLanguage: String = "English"
    @State private var targetLanguage: String = "Spanish"

    // Available languages (You can expand this list)
    let languages = ["English", "Spanish", "French", "German", "Chinese", "Japanese", "Italian"]

    var body: some View {
        VStack {
            TextField("Enter text to translate", text: $textToTranslate)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            // Source Language Picker
            Picker("Source Language", selection: $sourceLanguage) {
                ForEach(languages, id: \.self) {
                    Text($0)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .padding()

            // Target Language Picker
            Picker("Target Language", selection: $targetLanguage) {
                ForEach(languages, id: \.self) {
                    Text($0)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .padding()

            Button("Translate") {
                translateText()
            }
            .padding()

            Text(translatedText)
                .padding()

            // ScrollViewReader for automatic scrolling
            ScrollViewReader { scrollViewProxy in
                List(translationManager.history, id: \.self) { historyItem in
                    Text(historyItem)
                        .id(historyItem) // Assign a unique ID to each item for scrolling
                }
                .onChange(of: translationManager.history) { oldHistory, newHistory in
                    // Scroll to the last item when history changes
                    if let lastItem = newHistory.last {
                        withAnimation {
                            scrollViewProxy.scrollTo(lastItem, anchor: .bottom)
                        }
                    }
                }
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
        // Convert selected languages to appropriate language codes
        let sourceLanguageCode = languageCode(for: sourceLanguage)
        let targetLanguageCode = languageCode(for: targetLanguage)

        let encodedText = textToTranslate.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let apiUrl = "https://api.mymemory.translated.net/get?q=\(encodedText)&langpair=\(sourceLanguageCode)|\(targetLanguageCode)"

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

    // Helper function to map language names to language codes
    func languageCode(for language: String) -> String {
        switch language {
        case "English": return "en"
        case "Spanish": return "es"
        case "French": return "fr"
        case "German": return "de"
        case "Chinese": return "zh"
        case "Japanese": return "ja"
        case "Italian": return "it"
        default: return "en"  // Default to English if unknown
        }
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
