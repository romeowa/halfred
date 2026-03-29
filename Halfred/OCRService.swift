import AppKit
import Vision

enum OCRService {
    private static let queue = DispatchQueue(label: "com.halfred.ocr", qos: .userInitiated)

    static func recognizeText(in image: NSImage, completion: @escaping (String?) -> Void) {
        queue.async {
            guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            let request = VNRecognizeTextRequest { request, error in
                guard error == nil,
                      let observations = request.results as? [VNRecognizedTextObservation] else {
                    DispatchQueue.main.async { completion(nil) }
                    return
                }

                let text = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")

                DispatchQueue.main.async {
                    completion(text.isEmpty ? nil : text)
                }
            }

            request.recognitionLevel = .accurate
            request.automaticallyDetectsLanguage = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }
}
