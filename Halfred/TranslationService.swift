import Foundation

final class TranslationService {
    static let shared = TranslationService()

    struct Result {
        let translated: String
        let sourceLang: String
        let targetLang: String
    }

    func translate(text: String) async -> Result? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let targetLang = containsKorean(trimmed) ? "en" : "ko"

        guard let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=\(targetLang)&dt=t&q=\(encoded)") else {
            return nil
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [Any],
                  let sentences = json.first as? [[Any]] else {
                return nil
            }

            let translated = sentences.compactMap { $0.first as? String }.joined()
            let sourceLang = (json.count > 2 ? json[2] as? String : nil) ?? "auto"

            return Result(translated: translated, sourceLang: sourceLang, targetLang: targetLang)
        } catch {
            NSLog("Halfred: Translation failed: \(error)")
            return nil
        }
    }

    private func containsKorean(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            // Hangul Syllables (AC00-D7AF) + Jamo (1100-11FF, 3130-318F)
            (0xAC00...0xD7AF).contains(scalar.value) ||
            (0x1100...0x11FF).contains(scalar.value) ||
            (0x3130...0x318F).contains(scalar.value)
        }
    }
}
