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
        // Avoid encoding the text manually
        let encodedText = textToTranslate
        
        // Get the language codes based on user selection
        let sourceLangCode = languageCode(for: sourceLanguage)
        let targetLangCode = languageCode(for: targetLanguage)

        // Add a timestamp to prevent caching
        let timestamp = Date().timeIntervalSince1970

        // Construct the API URL with machine translation disabled (human translations only)
        let apiUrl = "https://api.mymemory.translated.net/get?q=\(encodedText)&langpair=\(sourceLangCode)|\(targetLangCode)&mt=0&tm=1&ts=\(timestamp)"

        // Print the apiUrl for debugging
        print("API URL: \(apiUrl)")

        guard let url = URL(string: apiUrl) else {
            print("Invalid API URL.")
            return
        }

        // Create a URLRequest and change to POST request with proper body encoding
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let bodyData = "q=\(textToTranslate)&langpair=\(sourceLangCode)|\(targetLangCode)&mt=0&tm=1&ts=\(timestamp)"
        request.httpBody = bodyData.data(using: .utf8)

        // API call
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Translation error: \(error.localizedDescription)")
                return
            }

            guard let data = data else {
                print("No data received from API.")
                return
            }

            // Print raw JSON response for debugging
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Raw JSON Response: \(jsonString)")
            }

            // Parse the response data
            do {
                let jsonResponse = try JSONDecoder().decode(MyMemoryResponse.self, from: data)

                // Check if the response status is 200 (success)
                if jsonResponse.responseStatus == 200 {
                    DispatchQueue.main.async {
                        var bestTranslation = jsonResponse.responseData.translatedText
                        
                        // Check if there are better matches from the "matches" array
                        if let matches = jsonResponse.matches {
                            if let highestMatch = matches.max(by: { $0.match < $1.match }) {
                                bestTranslation = highestMatch.translation
                            }
                        }

                        // Update the UI with the best translation
                        translatedText = bestTranslation

                        // Save the translation to history
                        translationManager.saveTranslation(original: textToTranslate, translated: translatedText)
                    }
                } else {
                    print("Error in API response: \(jsonResponse.responseDetails)")
                }
            } catch {
                print("Failed to decode translation response: \(error.localizedDescription)")
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
    let responseDetails: String
    let responseStatus: Int
    let matches: [TranslationMatch]?
}

struct TranslationData: Codable {
    let translatedText: String
}

struct TranslationMatch: Codable {
    let segment: String
    let translation: String
    let match: Double
}

#Preview {
    TranslationView()
}
