import SwiftUI

struct SettingsView: View {
    @ObservedObject private var claudeClient = ClaudeAPIClient.shared
    @ObservedObject private var monitor = AccessibilityMonitor.shared
    
    @State private var newApiKey: String = ""
    @State private var showKey = false
    @State private var saveStatus: String?
    @State private var expandedKeys = false
    
    var body: some View {
        Form {
            // API Keys Section
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Claude API Keys")
                            .font(.headline)
                        
                        Spacer()
                        
                        Text("\(claudeClient.apiKeysConfigured) configured")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Show configured keys count and failover status
                    if claudeClient.apiKeysConfigured > 1 {
                        HStack {
                            Image(systemName: "checkmark.shield.fill")
                                .foregroundColor(.green)
                            Text("Failover enabled - \(claudeClient.apiKeysConfigured) backup keys")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Add new key
                    HStack {
                        if showKey {
                            TextField("sk-ant-api...", text: $newApiKey)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))
                        } else {
                            SecureField("sk-ant-api...", text: $newApiKey)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        Button(action: { showKey.toggle() }) {
                            Image(systemName: showKey ? "eye.slash" : "eye")
                        }
                        .buttonStyle(.borderless)
                    }
                    
                    HStack {
                        Button("Add Key") {
                            addKey()
                        }
                        .disabled(newApiKey.isEmpty)
                        
                        if let status = saveStatus {
                            Text(status)
                                .foregroundColor(status.contains("✓") ? .green : .red)
                                .font(.caption)
                        }
                        
                        Spacer()
                        
                        Link("Get API Key", destination: URL(string: "https://console.anthropic.com/")!)
                            .font(.caption)
                    }
                    
                    // Key sources info
                    DisclosureGroup("Key sources", isExpanded: $expandedKeys) {
                        VStack(alignment: .leading, spacing: 4) {
                            KeySourceRow(source: "Environment", key: "ANTHROPIC_API_KEY", 
                                        found: ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] != nil)
                            KeySourceRow(source: "OpenClaw", key: "~/.openclaw/", 
                                        found: claudeClient.apiKeysConfigured > 0)
                            KeySourceRow(source: "App Keychain", key: "com.lulu-ai-companion", 
                                        found: KeychainHelper.get(key: "claude_api_key") != nil)
                        }
                        .font(.caption)
                        .padding(.top, 4)
                    }
                }
            } header: {
                Text("API Configuration")
            }
            
            // Permissions Section
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
            
            // About Section
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
                    
                    Divider()
                    
                    Text("Multiple API keys will be tried in sequence if one fails (rate limit or error). This provides automatic failover.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("About")
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 450, height: 450)
    }
    
    private func addKey() {
        guard !newApiKey.isEmpty else { return }
        
        if !newApiKey.hasPrefix("sk-ant-") {
            saveStatus = "❌ Invalid format (should start with sk-ant-)"
            return
        }
        
        let slot = claudeClient.nextAvailableSlot()
        claudeClient.addAPIKey(newApiKey, slot: slot)
        newApiKey = ""
        saveStatus = "✓ Key added"
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            saveStatus = nil
        }
    }
}

struct KeySourceRow: View {
    let source: String
    let key: String
    let found: Bool
    
    var body: some View {
        HStack {
            Image(systemName: found ? "checkmark.circle.fill" : "circle")
                .foregroundColor(found ? .green : .gray)
            Text(source)
                .frame(width: 80, alignment: .leading)
            Text(key)
                .foregroundColor(.secondary)
            Spacer()
        }
    }
}

#Preview {
    SettingsView()
}
