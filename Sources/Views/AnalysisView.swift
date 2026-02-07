import SwiftUI

/// Observable model for live updates
class AnalysisViewModel: ObservableObject {
    @Published var alert: ConnectionAlert
    @Published var recommendation: AIAnalysis.Recommendation = .unknown
    @Published var confidence: Double = 0
    @Published var summary: String = ""
    @Published var details: String = ""
    @Published var risks: [String] = []
    @Published var knownService: String?
    
    @Published var isLoadingEnrichment: Bool = true
    @Published var isLoadingAnalysis: Bool = true
    @Published var errorMessage: String?
    
    init(alert: ConnectionAlert) {
        self.alert = alert
    }
    
    func updateEnrichment(_ enrichedAlert: ConnectionAlert) {
        self.alert = enrichedAlert
        self.isLoadingEnrichment = false
    }
    
    func updateAnalysis(_ analysis: AIAnalysis) {
        self.recommendation = analysis.recommendation
        self.confidence = analysis.confidence
        self.summary = analysis.summary
        self.details = analysis.details
        self.risks = analysis.risks
        self.knownService = analysis.knownService
        self.isLoadingAnalysis = false
    }
    
    func setError(_ message: String) {
        self.errorMessage = message
        self.isLoadingAnalysis = false
    }
}

struct AnalysisView: View {
    @ObservedObject var viewModel: AnalysisViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Recommendation Header
                HStack(spacing: 12) {
                    if viewModel.isLoadingAnalysis {
                        ProgressView()
                            .scaleEffect(1.5)
                            .frame(width: 48, height: 48)
                    } else {
                        Text(viewModel.recommendation.emoji)
                            .font(.system(size: 48))
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        if viewModel.isLoadingAnalysis {
                            Text("Analyzing...")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)
                            Text("Asking Claude for security assessment")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text(viewModel.recommendation.rawValue)
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(recommendationColor)
                            
                            if let service = viewModel.knownService {
                                Text(service)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            // Confidence bar
                            HStack(spacing: 4) {
                                Text("Confidence:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                ProgressView(value: viewModel.confidence)
                                    .frame(width: 80)
                                
                                Text("\(Int(viewModel.confidence * 100))%")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Spacer()
                }
                .padding()
                .background(recommendationColor.opacity(0.1))
                .cornerRadius(12)
                
                // Error message
                if let error = viewModel.errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(error)
                            .foregroundColor(.red)
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }
                
                // Summary
                if !viewModel.summary.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Summary")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(viewModel.summary)
                            .font(.body)
                    }
                }
                
                // Connection Details
                GroupBox("Connection Details") {
                    VStack(alignment: .leading, spacing: 8) {
                        DetailRow(label: "Process", value: viewModel.alert.processName)
                        DetailRow(label: "Path", value: viewModel.alert.processPath)
                        DetailRow(label: "Destination", value: "\(viewModel.alert.ipAddress):\(viewModel.alert.port)")
                        DetailRow(label: "Protocol", value: viewModel.alert.proto)
                        
                        if viewModel.isLoadingEnrichment {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.7)
                                Text("Loading WHOIS/DNS...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            if !viewModel.alert.reverseDNS.isEmpty {
                                DetailRow(label: "DNS", value: viewModel.alert.reverseDNS)
                            }
                            if let geo = viewModel.alert.geoLocation {
                                DetailRow(label: "Location", value: geo)
                            }
                            if let whois = viewModel.alert.whoisData {
                                DetailRow(label: "WHOIS", value: whois)
                            }
                        }
                    }
                }
                
                // Details
                if !viewModel.details.isEmpty {
                    GroupBox("Analysis") {
                        Text(viewModel.details)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                
                // Risks
                if !viewModel.risks.isEmpty {
                    GroupBox("Risks") {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(viewModel.risks, id: \.self) { risk in
                                HStack(alignment: .top) {
                                    Text("•")
                                        .foregroundColor(.orange)
                                    Text(risk)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                
                Spacer()
            }
            .padding()
        }
        .frame(minWidth: 380, minHeight: 300)
    }
    
    private var recommendationColor: Color {
        if viewModel.isLoadingAnalysis { return .gray }
        switch viewModel.recommendation {
        case .allow: return .green
        case .block: return .red
        case .caution: return .orange
        case .unknown: return .gray
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top) {
            Text(label + ":")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .trailing)
            
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
            
            Spacer()
        }
    }
}
