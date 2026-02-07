import SwiftUI

struct SettingsView: View {
    @ObservedObject private var claudeClient = ClaudeAPIClient.shared
    @ObservedObject private var monitor = AccessibilityMonitor.shared
    
    @State private var apiKey: String = ""
    @State private var showKey = false
    @State private var saveStatus: String?
    
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Claude API Key")
                        .font(.headline)
                    
                    HStack {
                        if showKey {
                            TextField("sk-ant-api...", text: $apiKey)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))
                        } else {
                            SecureField("sk-ant-api...", text: $apiKey)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        Button(action: { showKey.toggle() }) {
                            Image(systemName: showKey ? "eye.slash" : "eye")
                        }
                        .buttonStyle(.borderless)
                    }
                    
                    HStack {
                        Button("Save Key") {
                            claudeClient.apiKey = apiKey
                            saveStatus = "✓ Saved"
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                saveStatus = nil
                            }
                        }
                        .disabled(apiKey.isEmpty)
                        
                        if let status = saveStatus {
                            Text(status)
                                .foregroundColor(.green)
                                .font(.caption)
                        }
                        
                        Spacer()
                        
                        Link("Get API Key", destination: URL(string: "https://console.anthropic.com/")!)
                            .font(.caption)
                    }
                }
            } header: {
                Text("API Configuration")
            }
            
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Circle()
                            .fill(monitor.accessibilityEnabled ? Color.green : Color.orange)
                            .frame(width: 10, height: 10)
                        
                        Text("Accessibility Permission")
                        
                        Spacer()
                        
                        Text(monitor.accessibilityEnabled ? "Granted" : "Required")
                            .foregroundColor(.secondary)
                    }
                    
                    if !monitor.accessibilityEnabled {
                        Text("This app needs Accessibility access to detect LuLu alert windows.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button("Open System Preferences") {
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                        }
                    }
                    
                    HStack {
                        Circle()
                            .fill(monitor.isMonitoring ? Color.green : Color.gray)
                            .frame(width: 10, height: 10)
                        
                        Text("Monitoring Status")
                        
                        Spacer()
                        
                        Toggle("", isOn: Binding(
                            get: { monitor.isMonitoring },
                            set: { enabled in
                                if enabled {
                                    monitor.startMonitoring()
                                } else {
                                    monitor.stopMonitoring()
                                }
                            }
                        ))
                        .toggleStyle(.switch)
                    }
                }
            } header: {
                Text("Permissions")
            }
            
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("How it works:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("""
                    1. LuLu shows a firewall alert
                    2. This app detects the alert window
                    3. Extracts IP, process, and connection info
                    4. Enriches with WHOIS/geo data
                    5. Sends to Claude for analysis
                    6. Shows AI recommendation
                    """)
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            } header: {
                Text("About")
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 450, height: 400)
        .onAppear {
            apiKey = claudeClient.apiKey ?? ""
        }
    }
}

#Preview {
    SettingsView()
}
