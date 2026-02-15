import SwiftUI

struct WelcomeView: View {
    @StateObject private var aiClient = AIClient.shared
    @StateObject private var monitor = AccessibilityMonitor.shared
    
    @State private var apiKey: String = ""
    @State private var showKey = false
    @State private var currentStep = 0
    @State private var isChecking = false
    @State private var errorMessage: String?
    @State private var foundExistingKeys = false
    
    var onComplete: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "shield.checkered")
                    .font(.system(size: 64))
                    .foregroundColor(.blue)
                
                Text("Welcome to LuLu AI Companion")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("AI-powered firewall analysis")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 30)
            .padding(.bottom, 20)
            
            Divider()
            
            // Content based on step
            VStack(spacing: 20) {
                switch currentStep {
                case 0:
                    checkingExistingKeysView
                case 1:
                    accessibilitySetupView
                case 2:
                    apiKeySetupView
                case 3:
                    completionView
                default:
                    EmptyView()
                }
            }
            .padding(30)
            .frame(maxHeight: .infinity)
            
            Divider()
            
            // Footer with navigation
            HStack {
                Spacer()
                
                // Step indicators
                HStack(spacing: 8) {
                    ForEach(0..<4) { step in
                        Circle()
                            .fill(step <= currentStep ? Color.blue : Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
                
                Spacer()
                
                if currentStep == 3 {
                    Button("Get Started") {
                        complete()
                    }
                    .buttonStyle(.borderedProminent)
                } else if canAdvance {
                    Button(currentStep == 0 ? "Continue" : "Next") {
                        advanceStep()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
        .frame(width: 500, height: 580)
        .onAppear {
            checkForExistingKeys()
        }
    }
    
    // MARK: - Step Views
    
    private var checkingExistingKeysView: some View {
        VStack(spacing: 20) {
            if isChecking {
                ProgressView()
                    .scaleEffect(1.5)
                Text("Checking for existing API keys...")
                    .foregroundColor(.secondary)
            } else if foundExistingKeys {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.green)
                
                Text("Found \(aiClient.apiKeysConfigured) API key(s)!")
                    .font(.headline)
                
                Text("We detected existing Claude API keys from OpenClaw or environment variables. You're all set!")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                
                if aiClient.apiKeysConfigured > 1 {
                    Text("Multiple keys will be used for automatic failover.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                Image(systemName: "key.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.orange)
                
                Text("No API Key Found")
                    .font(.headline)
                
                Text("To use AI-powered analysis, you'll need an API key. Get a free one from platform.3mate.io, or use your own Claude API key from Anthropic.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var detectedProvider: AIProvider? {
        guard !apiKey.isEmpty else { return nil }
        let cleaned = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.count > 10 else { return nil }
        return AIProvider.detect(from: cleaned)
    }
    
    private var apiKeySetupView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Enter your API Key")
                .font(.headline)
            
            HStack {
                if showKey {
                    TextField("Paste your API key here", text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                } else {
                    SecureField("Paste your API key here", text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                }
                
                Button(action: { showKey.toggle() }) {
                    Image(systemName: showKey ? "eye.slash" : "eye")
                }
                .buttonStyle(.borderless)
            }
            
            // Show detected provider
            if let provider = detectedProvider {
                HStack {
                    Image(systemName: provider.icon)
                        .foregroundColor(.green)
                    Text("Detected: \(provider.rawValue)")
                        .font(.caption)
                        .foregroundColor(.green)
                        .fontWeight(.medium)
                }
            }
            
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            HStack {
                if !apiKey.isEmpty {
                    Spacer()
                    Button("Verify Key") {
                        verifyKey()
                    }
                    .disabled(isChecking)
                }
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Supported providers:")
                    .font(.caption)
                    .fontWeight(.medium)
                
                Link(destination: URL(string: "https://platform.3mate.io")!) {
                    HStack {
                        Image(systemName: "star.circle")
                        Text("3mate Platform (free trial)")
                    }
                }
                .font(.caption)
                
                Link(destination: URL(string: "https://console.anthropic.com/")!) {
                    HStack {
                        Image(systemName: "brain.head.profile")
                        Text("Anthropic (Claude)")
                    }
                }
                .font(.caption)
                
                Link(destination: URL(string: "https://platform.openai.com/api-keys")!) {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("OpenAI (GPT)")
                    }
                }
                .font(.caption)
                
                Link(destination: URL(string: "https://aistudio.google.com/apikey")!) {
                    HStack {
                        Image(systemName: "diamond")
                        Text("Google (Gemini)")
                    }
                }
                .font(.caption)
                
                Divider()
                    .padding(.vertical, 4)
                
                Text("• Your key is stored locally with obfuscation")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("• You can manage keys later in Settings")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var accessibilitySetupView: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: monitor.accessibilityEnabled ? "checkmark.circle.fill" : "hand.raised.fill")
                    .font(.system(size: 48))
                    .foregroundColor(monitor.accessibilityEnabled ? .green : .orange)
                
                Text("Accessibility Permission")
                    .font(.headline)
                
                if monitor.accessibilityEnabled {
                    Text("Accessibility access is enabled! The app can now detect LuLu alert windows.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                } else {
                    Text("This app needs Accessibility permission to detect when LuLu shows a firewall alert.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                    
                    Button("Open System Settings") {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Check Again") {
                        _ = monitor.checkAccessibilityPermission()
                    }
                    .buttonStyle(.bordered)
                    
                    // Compact note for updated app
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                        Text("Updated the app? Remove the old entry in System Settings > Accessibility, then re-add it.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(10)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
    }
    
    private var completionView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)
            
            Text("You're All Set!")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: aiClient.hasAPIKey ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(aiClient.hasAPIKey ? .green : .red)
                    Text("API Key: \(aiClient.apiKeysConfigured) configured")
                }
                
                HStack {
                    Image(systemName: monitor.accessibilityEnabled ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .foregroundColor(monitor.accessibilityEnabled ? .green : .orange)
                    Text("Accessibility: \(monitor.accessibilityEnabled ? "Enabled" : "Not enabled (optional)")")
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
            
            Text("The app will run in your menu bar and automatically analyze connections when LuLu shows an alert.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .font(.caption)
        }
    }
    
    // MARK: - Logic
    
    private var canAdvance: Bool {
        switch currentStep {
        case 0:
            return !isChecking
        case 1:
            return monitor.accessibilityEnabled
        case 2:
            return foundExistingKeys || !apiKey.isEmpty
        default:
            return true
        }
    }
    
    private func checkForExistingKeys() {
        isChecking = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            aiClient.refreshKeyCount()
            foundExistingKeys = aiClient.hasAPIKey
            isChecking = false
            
            // If keys found, skip to step 2
            if foundExistingKeys {
                currentStep = 0 // Show the "found keys" message first
            }
        }
    }
    
    private func advanceStep() {
        withAnimation {
            if currentStep == 0 {
                // Go to accessibility
                currentStep = 1
            } else if currentStep == 1 {
                // Accessibility done, go to API key
                if foundExistingKeys {
                    // Skip API key entry if we already have keys
                    currentStep = 3
                } else {
                    currentStep = 2
                }
            } else if currentStep == 2 && !apiKey.isEmpty {
                // Save the key
                aiClient.addAPIKey(apiKey)
                foundExistingKeys = true
                currentStep = 3
            } else {
                currentStep += 1
            }
        }
    }
    
    private func verifyKey() {
        guard AIProvider.isValidKey(apiKey) else {
            errorMessage = "Invalid key format. Supported: sk-ant-api- (Anthropic), sk- (OpenAI), AIza (Gemini), sk-3mate- (3mate). OAuth/setup tokens not accepted."
            return
        }
        
        isChecking = true
        errorMessage = nil
        
        // Simple validation - just check format for now
        // Full validation would require an API call
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isChecking = false
            if apiKey.count > 20 {
                aiClient.addAPIKey(apiKey)
                currentStep = 2
            } else {
                errorMessage = "Key appears too short"
            }
        }
    }
    
    private func complete() {
        // Mark setup as complete
        UserDefaults.standard.set(true, forKey: "hasCompletedSetup")
        
        // onComplete handles window closing and starting monitoring
        onComplete?()
    }
}

#Preview {
    WelcomeView()
}
