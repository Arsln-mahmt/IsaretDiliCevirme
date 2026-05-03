//
//  PredictionService.swift
//  IsaretDiliCevirme
//
//  Created by Mahmut Arslan on 28.03.2026.
//

import Foundation
import UIKit

/// Response structure matching the FastAPI TranslationResponse model.
struct PredictionResponse: Decodable {
    let success: Bool
    let predicted_text: String
    let confidence_score: Double
    let message: String
}

/// Service responsible for sending camera frames to the FastAPI backend.
final class PredictionService: @unchecked Sendable {
    
    /// The URL of the FastAPI backend endpoint.
    /// - Note: If testing on a real iOS device, replace `127.0.0.1` with your Mac's IP address on the local Wi-Fi.
    ///         For Simulator, use `127.0.0.1`.
    #if targetEnvironment(simulator)
    private let endpointURL = URL(string: "http://127.0.0.1:8000/api/v1/predict")!
    #else
    private let endpointURL = URL(string: "http://192.168.1.103:8000/api/v1/predict")!
    #endif
    
    /// A dedicated URLSession with a short timeout for live camera usage.
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5    // 5 seconds max per request
        config.timeoutIntervalForResource = 10
        return URLSession(configuration: config)
    }()
    
    /// Sends a UIImage to the backend for sign language prediction.
    /// - Parameter image: The camera frame to process.
    /// - Returns: The prediction response if successful, nil otherwise.
    func predictFromImage(image: UIImage) async throws -> PredictionResponse? {
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            print("[PredictionService] ❌ Could not convert image to JPEG.")
            return nil
        }
        
        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"frame.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        print("[PredictionService] 📡 Sending frame to \(endpointURL.absoluteString) (\(imageData.count) bytes)")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("[PredictionService] ❌ Invalid response type")
            return nil
        }
        
        print("[PredictionService] 📥 Response status: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            let result = try decoder.decode(PredictionResponse.self, from: data)
            print("[PredictionService] ✅ Predicted: '\(result.predicted_text)' (confidence: \(String(format: "%.2f", result.confidence_score)))")
            return result
        } else {
            let bodyString = String(data: data, encoding: .utf8) ?? "N/A"
            print("[PredictionService] ❌ Server error \(httpResponse.statusCode): \(bodyString)")
            return nil
        }
    }
}
