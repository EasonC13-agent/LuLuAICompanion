import Foundation

/// Client for Claude API to analyze connection alerts
class ClaudeAPIClient: ObservableObject {
    @Published var isAnalyzing = false
    @Published var lastError: String?
    
    private let baseURL = "https://api.anthropic.com/v1/messages"
    private let model = "claude-sonnet-4-20250514"
    
    static let shared = ClaudeAPIClient()
    
    private init() {}
    
    // MARK: - API Key Management
    
    var apiKey: String? {
        get { KeychainHelper.get(key: "claude_api_key") }
        set {
            if let value = newValue {
                KeychainHelper.save(key: "claude_api_key", value: value)
            } else {
                KeychainHelper.delete(key: "claude_api_key")
            }
        }
    }
    
    var hasAPIKey: Bool {
        guard let key = apiKey else { return false }
        return !key.isEmpty
    }
    
    // MARK: - Analysis
    
    func analyzeConnection(_ alert: ConnectionAlert) async throws -> AIAnalysis {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            throw APIError.noAPIKey
        }
        
        await MainActor.run { isAnalyzing = true }
        defer { Task { @MainActor in isAnalyzing = false } }
        
        let prompt = buildPrompt(for: alert)
        let response = try await sendRequest(prompt: prompt)
        let analysis = parseResponse(response, for: alert)
        
        return analysis
    }
    
    // MARK: - Prompt Building
    
    private func buildPrompt(for alert: ConnectionAlert) -> String {
        """
        You are a macOS firewall security advisor. Analyze this outgoing network connection and provide a security recommendation.
        
        \(alert.promptDescription)
        
        Based on this information:
        1. Identify what service/application is likely making this connection
        2. Assess the security risk (is this expected behavior?)
        3. Recommend: ALLOW, BLOCK, or CAUTION
        4. Explain your reasoning briefly
        
        Respond in this exact JSON format:
        {
            "recommendation": "ALLOW" | "BLOCK" | "CAUTION",
            "confidence": 0.0-1.0,
            "known_service": "Name of known service if identified, or null",
            "summary": "One-line summary",
            "details": "2-3 sentence explanation",
            "risks": ["risk1", "risk2"]
        }
        
        Common safe connections:
        - Apple services (*.apple.com, *.icloud.com)
        - Google (*.google.com, *.googleapis.com, *.1e100.net)
        - Microsoft (*.microsoft.com)
        - CDNs (*.cloudflare.com, *.akamai.com, *.fastly.net)
        
        Be cautious about:
        - Unknown IPs without reverse DNS
        - Connections to unusual ports
        - Processes connecting to unexpected destinations
        - Newly installed or unsigned applications
        """
    }
    
    // MARK: - API Request
    
    private func sendRequest(prompt: String) async throws -> String {
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey!, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.httpError(statusCode: httpResponse.statusCode, message: errorBody)
        }
        
        // Parse Claude response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstContent = content.first,
              let text = firstContent["text"] as? String else {
            throw APIError.parseError
        }
        
        return text
    }
    
    // MARK: - Response Parsing
    
    private func parseResponse(_ response: String, for alert: ConnectionAlert) -> AIAnalysis {
        // Try to extract JSON from response
        var analysis = AIAnalysis(alert: alert)
        
        // Find JSON in response (Claude might include explanation text around it)
        if let jsonStart = response.firstIndex(of: "{"),
           let jsonEnd = response.lastIndex(of: "}") {
            let jsonString = String(response[jsonStart...jsonEnd])
            
            if let data = jsonString.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                
                // Parse recommendation
                if let rec = json["recommendation"] as? String {
                    switch rec.uppercased() {
                    case "ALLOW": analysis.recommendation = .allow
                    case "BLOCK": analysis.recommendation = .block
                    case "CAUTION": analysis.recommendation = .caution
                    default: analysis.recommendation = .unknown
                    }
                }
                
                // Parse other fields
                analysis.confidence = json["confidence"] as? Double ?? 0.5
                analysis.summary = json["summary"] as? String ?? ""
                analysis.details = json["details"] as? String ?? ""
                analysis.risks = json["risks"] as? [String] ?? []
                analysis.knownService = json["known_service"] as? String
            }
        }
        
        // Fallback: if JSON parsing failed, use the raw response
        if analysis.summary.isEmpty {
            analysis.summary = "See details"
            analysis.details = response
        }
        
        return analysis
    }
    
    // MARK: - Errors
    
    enum APIError: LocalizedError {
        case noAPIKey
        case invalidResponse
        case httpError(statusCode: Int, message: String)
        case parseError
        
        var errorDescription: String? {
            switch self {
            case .noAPIKey:
                return "No API key configured. Please add your Claude API key in settings."
            case .invalidResponse:
                return "Invalid response from server"
            case .httpError(let code, let message):
                return "HTTP \(code): \(message)"
            case .parseError:
                return "Failed to parse API response"
            }
        }
    }
}
