import SwiftUI

struct AnalysisView: View {
    let analysis: AIAnalysis
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Recommendation Header
                HStack(spacing: 12) {
                    Text(analysis.recommendation.emoji)
                        .font(.system(size: 48))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(analysis.recommendation.rawValue)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(recommendationColor)
                        
                        if let service = analysis.knownService {
                            Text(service)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        // Confidence bar
                        HStack(spacing: 4) {
                            Text("Confidence:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            ProgressView(value: analysis.confidence)
                                .frame(width: 80)
                            
                            Text("\(Int(analysis.confidence * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                }
                .padding()
                .background(recommendationColor.opacity(0.1))
                .cornerRadius(12)
                
                // Summary
                if !analysis.summary.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Summary")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(analysis.summary)
                            .font(.body)
                    }
                }
                
                // Connection Details
                GroupBox("Connection Details") {
                    VStack(alignment: .leading, spacing: 8) {
                        DetailRow(label: "Process", value: analysis.alert.processName)
                        DetailRow(label: "Path", value: analysis.alert.processPath)
                        DetailRow(label: "Destination", value: "\(analysis.alert.ipAddress):\(analysis.alert.port)")
                        DetailRow(label: "Protocol", value: analysis.alert.proto)
                        if !analysis.alert.reverseDNS.isEmpty {
                            DetailRow(label: "DNS", value: analysis.alert.reverseDNS)
                        }
                        if let geo = analysis.alert.geoLocation {
                            DetailRow(label: "Location", value: geo)
                        }
                        if let whois = analysis.alert.whoisData {
                            DetailRow(label: "WHOIS", value: whois)
                        }
                    }
                }
                
                // Details
                if !analysis.details.isEmpty {
                    GroupBox("Analysis") {
                        Text(analysis.details)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                
                // Risks
                if !analysis.risks.isEmpty {
                    GroupBox("Risks") {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(analysis.risks, id: \.self) { risk in
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
        switch analysis.recommendation {
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

#Preview {
    AnalysisView(analysis: AIAnalysis(
        alert: ConnectionAlert(
            processName: "Python",
            processPath: "/Library/Frameworks/Python.framework/Versions/3.11/Resources/Python.app",
            processID: "73810",
            ipAddress: "142.251.170.95",
            port: "443",
            proto: "TCP",
            reverseDNS: "tc-in-f95.1e100.net"
        ),
        recommendation: .allow,
        confidence: 0.92,
        summary: "This is a Google Cloud service connection",
        details: "Python is connecting to Google Cloud infrastructure (1e100.net is Google's internal domain). This is typical for applications using Google APIs, Cloud SDK, or Firebase.",
        risks: [],
        knownService: "Google Cloud Platform"
    ))
}
