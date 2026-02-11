import SwiftUI

struct SettingsView: View {
    @ObservedObject private var aiClient = AIClient.shared
    @ObservedObject private var monitor = AccessibilityMonitor.shared
    @ObservedObject private var history = HistoryManager.shared
    
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
                        Text("AI Provider Keys")
                            .font(.headline)
                        
                        Spacer()
                        
                        Text("\(aiClient.apiKeysConfigured) configured")
                            .font(.caption)
                            .foregroundColor(aiClient.apiKeysConfigured > 0 ? .green : .red)
                    }
                    
                    // Show configured keys count and failover status
                    if aiClient.apiKeysConfigured > 1 {
                        HStack {
                            Image(systemName: "checkmark.shield.fill")
                                .foregroundColor(.green)
                            Text("Failover enabled across providers")
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
                            ForEach(aiClient.listKeys(), id: \.slot) { keyInfo in
                                if keyInfo.hasKey {
                                    HStack {
                                        if let provider = keyInfo.provider {
                                            Image(systemName: provider.icon)
                                                .foregroundColor(.orange)
                                                .help(provider.rawValue)
                                        } else {
                                            Image(systemName: "key.fill")
                                                .foregroundColor(.orange)
                                        }
                                        Text(keyInfo.prefix ?? "sk-...")
                                            .font(.caption.monospaced())
                                        if let provider = keyInfo.provider {
                                            Text("(\(provider.rawValue))")
                                                .font(.caption2)
                                                .foregroundColor(.blue)
                                        }
                                        Spacer()
                                        Text("Slot \(keyInfo.slot)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        Button(action: {
                                            aiClient.removeAPIKey(slot: keyInfo.slot)
                                        }) {
                                            Image(systemName: "trash")
                                                .foregroundColor(.red)
                                        }
                                        .buttonStyle(.borderless)
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                            
                            if aiClient.apiKeysConfigured == 0 && ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] == nil {
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
                            TextField("sk-... or AIza...", text: $newApiKey)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.caption, design: .monospaced))
                        } else {
                            SecureField("sk-... or AIza...", text: $newApiKey)
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
                    }
                    
                    // Provider links
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Get an API key:")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        HStack(spacing: 12) {
                            Link("Anthropic", destination: URL(string: "https://console.anthropic.com/")!)
                            Link("OpenAI", destination: URL(string: "https://platform.openai.com/api-keys")!)
                            Link("Gemini", destination: URL(string: "https://aistudio.google.com/apikey")!)
                            Link("3mate", destination: URL(string: "https://platform.3mate.io")!)
                        }
                        .font(.caption2)
                    }
                    
                    Text("Supports Anthropic (sk-ant-), OpenAI (sk-), Gemini (AIza), and 3mate keys. Multiple keys provide automatic failover.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("API Configuration")
            }
            
            // History Section
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Max History Entries")
                        Spacer()
                        Stepper("\(history.maxCount)", onIncrement: {
                            history.maxCount = min(1000, history.maxCount + 10)
                        }, onDecrement: {
                            history.maxCount = max(10, history.maxCount - 10)
                        })
                    }
                    
                    Text("Currently \(history.entries.count) entries saved")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("History")
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
        .frame(width: 420, height: 600)
    }
    
    private func addKey() {
        guard !newApiKey.isEmpty else { return }
        
        let cleanedKey = newApiKey.components(separatedBy: .whitespacesAndNewlines).joined()
        
        if !AIProvider.isValidKey(cleanedKey) {
            saveStatus = "❌ Invalid format (use sk-ant-, sk-, AIza, or sk-3mate-)"
            return
        }
        
        let provider = AIProvider.detect(from: cleanedKey)
        let slot = aiClient.nextAvailableSlot()
        aiClient.addAPIKey(cleanedKey, slot: slot)
        newApiKey = ""
        saveStatus = "✓ \(provider.rawValue) key added to slot \(slot)"
        
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
