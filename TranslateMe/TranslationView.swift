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
    @State private var isTranslating = false
    @ObservedObject var translationManager = TranslationManager()

    // Default languages
    @State private var sourceLanguage: String = "English"
    @State private var targetLanguage: String = "Spanish"

    // Available languages (You can expand this list)
    let languages = ["English", "Spanish", "French", "German", "Chinese", "Japanese", "Italian"]

    var body: some View {
            ZStack {
                // Gradient background
                LinearGradient(gradient: Gradient(colors: [Color.blue, Color.purple]), startPoint: .top, endPoint: .bottom)
                    .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 20) {
                    Text("TranslateMe")
                        .font(.largeTitle)
                        .foregroundColor(.white)
                        .padding()

                    // TextField for entering the text to translate
                    TextField("Enter text to translate", text: $textToTranslate)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding()
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(10)
                        .shadow(radius: 5)
                        .padding(.horizontal)

                    // Source Language Picker
                    Picker("Source Language", selection: $sourceLanguage) {
                        ForEach(languages, id: \.self) {
                            Text($0)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .padding()
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(10)
                    .shadow(radius: 5)
                    .padding(.horizontal)

                    // Target Language Picker
                    Picker("Target Language", selection: $targetLanguage) {
                        ForEach(languages, id: \.self) {
                            Text($0)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .padding()
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(10)
                    .shadow(radius: 5)
                    .padding(.horizontal)

                    // Translate Button or ProgressView based on isTranslating state
                    if isTranslating {
                        ProgressView("Translating...")
                            .progressViewStyle(CircularProgressViewStyle())
                            .padding()
                    } else {
                        Button(action: {
                            isTranslating = true
                            translateText()
                        }) {
                            Text("Translate")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(width: 200)
                                .background(LinearGradient(gradient: Gradient(colors: [Color.blue, Color.purple]), startPoint: .leading, endPoint: .trailing))
                                .cornerRadius(10)
                                .shadow(radius: 10)
                        }
                        .padding(.top, 10)
                    }

                    // Display translated text
                    Text(translatedText)
                        .font(.title2)
                        .padding()
                        .foregroundColor(.white)
                        .opacity(translatedText.isEmpty ? 0 : 1)
                        .animation(.easeIn, value: translatedText)  // Specify the value being animated

                    // ScrollViewReader for translation history
                    ScrollViewReader { scrollViewProxy in
                        List(translationManager.history, id: \.self) { historyItem in
                            Text(historyItem)
                                .padding()
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(10)
                                .shadow(radius: 5)
                        }
                        .onChange(of: translationManager.history) { _, newHistory in
                            if let lastItem = newHistory.last {
                                withAnimation {
                                    scrollViewProxy.scrollTo(lastItem, anchor: .bottom)
                                }
                            }
                        }
                        .padding()
                        .frame(height: 200)
                    }

                    // Clear History Button
                    Button("Clear History") {
                        translationManager.clearHistory()
                    }
                    .padding()
                    .foregroundColor(.white)
                    .background(Color.red)
                    .cornerRadius(10)
                }
                .padding()
            }
            .onAppear {
                translationManager.loadHistory() // Load history on app start
            }
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
            isTranslating = false // Stop the loading animation
            return
        }

        // API call
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Translation error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    isTranslating = false // Stop the loading animation on error
                }
                return
            }

            guard let data = data else {
                print("No data received from API.")
                DispatchQueue.main.async {
                    isTranslating = false // Stop the loading animation if no data is received
                }
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
                            // Filter matches to find better quality matches
                            let goodMatches = matches.filter { $0.match > 0.9 && !$0.translation.contains("Estudio") }
                            if let highestMatch = goodMatches.max(by: { $0.match < $1.match }) {
                                bestTranslation = highestMatch.translation
                            }
                        }

                        // Update the UI with the best translation
                        translatedText = bestTranslation

                        // Save the translation to history
                        translationManager.saveTranslation(original: textToTranslate, translated: translatedText)

                        // Stop the loading animation
                        isTranslating = false
                    }
                } else {
                    print("Error in API response: \(jsonResponse.responseDetails)")
                    DispatchQueue.main.async {
                        isTranslating = false // Stop the loading animation if response is not successful
                    }
                }
            } catch {
                print("Failed to decode translation response: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    isTranslating = false // Stop the loading animation if decoding fails
                }
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
