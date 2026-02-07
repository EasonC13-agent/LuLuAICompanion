import SwiftUI

struct SettingsView: View {
    @ObservedObject private var claudeClient = ClaudeAPIClient.shared
    @ObservedObject private var monitor = AccessibilityMonitor.shared
    
    @State private var newApiKey: String = ""
    @State private var showKey = false
    @State private var saveStatus: String?
    @State private var expandedKeys = true
    
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
                            .foregroundColor(claudeClient.apiKeysConfigured > 0 ? .green : .red)
                    }
                    
                    // Show configured keys count and failover status
                    if claudeClient.apiKeysConfigured > 1 {
                        HStack {
                            Image(systemName: "checkmark.shield.fill")
                                .foregroundColor(.green)
                            Text("Failover enabled")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // List of configured keys
                    DisclosureGroup("Manage Keys", isExpanded: $expandedKeys) {
                        VStack(alignment: .leading, spacing: 8) {
                            // Environment key (read-only)
                            if ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] != nil {
                                HStack {
                                    Image(systemName: "terminal")
                                        .foregroundColor(.blue)
                                    Text("ENV: ANTHROPIC_API_KEY")
                                        .font(.caption.monospaced())
                                    Spacer()
                                    Text("(read-only)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                            
                            // Keychain keys
                            ForEach(claudeClient.listKeys(), id: \.slot) { keyInfo in
                                if keyInfo.hasKey {
                                    HStack {
                                        Image(systemName: "key.fill")
                                            .foregroundColor(.orange)
                                        Text(keyInfo.prefix ?? "sk-ant-...")
                                            .font(.caption.monospaced())
                                        Spacer()
                                        Text("Slot \(keyInfo.slot)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        Button(action: {
                                            claudeClient.removeAPIKey(slot: keyInfo.slot)
                                        }) {
                                            Image(systemName: "trash")
                                                .foregroundColor(.red)
                                        }
                                        .buttonStyle(.borderless)
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                            
                            if claudeClient.apiKeysConfigured == 0 && ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] == nil {
                                Text("No API keys configured")
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .padding(.vertical, 4)
                            }
                        }
                        .padding(.top, 8)
                    }
                    
                    Divider()
                    
                    // Add new key
                    Text("Add New Key")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack {
                        if showKey {
                            TextField("sk-ant-api03-...", text: $newApiKey)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.caption, design: .monospaced))
                        } else {
                            SecureField("sk-ant-api03-...", text: $newApiKey)
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
                    
                    Text("Multiple keys provide automatic failover when one hits rate limits or fails.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
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
                        Text("Required to detect LuLu alert windows.")
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
                        
                        Text("Monitoring")
                        
                        Spacer()
                        
                        Toggle("", isOn: Binding(
                            get: { monitor.isMonitoring },
                            set: { enabled in
                                if enabled { monitor.startMonitoring() }
                                else { monitor.stopMonitoring() }
                            }
                        ))
                        .toggleStyle(.switch)
                    }
                }
            } header: {
                Text("Permissions")
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 420, height: 480)
    }
    
    private func addKey() {
        guard !newApiKey.isEmpty else { return }
        
        if !newApiKey.hasPrefix("sk-ant-") {
            saveStatus = "❌ Invalid format"
            return
        }
        
        let slot = claudeClient.nextAvailableSlot()
        claudeClient.addAPIKey(newApiKey, slot: slot)
        newApiKey = ""
        saveStatus = "✓ Added to slot \(slot)"
        
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
