import Foundation

/// AI analysis result from Claude
struct AIAnalysis: Identifiable {
    let id = UUID()
    let timestamp: Date
    let alert: ConnectionAlert
    
    // AI Response
    var recommendation: Recommendation
    var confidence: Double  // 0.0 - 1.0
    var summary: String
    var details: String
    var risks: [String]
    var knownService: String?
    
    enum Recommendation: String, CaseIterable {
        case allow = "Allow"
        case block = "Block"
        case caution = "Caution"
        case unknown = "Unknown"
        
        var emoji: String {
            switch self {
            case .allow: return "✅"
            case .block: return "🚫"
            case .caution: return "⚠️"
            case .unknown: return "❓"
            }
        }
        
        var color: String {
            switch self {
            case .allow: return "green"
            case .block: return "red"
            case .caution: return "yellow"
            case .unknown: return "gray"
            }
        }
    }
    
    init(alert: ConnectionAlert,
         recommendation: Recommendation = .unknown,
         confidence: Double = 0.0,
         summary: String = "",
         details: String = "",
         risks: [String] = [],
         knownService: String? = nil) {
        self.timestamp = Date()
        self.alert = alert
        self.recommendation = recommendation
        self.confidence = confidence
        self.summary = summary
        self.details = details
        self.risks = risks
        self.knownService = knownService
    }
}
