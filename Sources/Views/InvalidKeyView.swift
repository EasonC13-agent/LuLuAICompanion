import SwiftUI

struct InvalidKeyView: View {
    var onDismiss: () -> Void
    var onAddKey: (String) -> Void
    
    @State private var apiKey: String = ""
    @State private var showKey = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "key.slash")
                    .font(.system(size: 48))
                    .foregroundColor(.red)
                
                Text("API Key Invalid or Missing")
                    .font(.headline)
                
                Text("Your Claude API key is invalid or all keys have failed. Please add a valid key to continue.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Key input
            VStack(alignment: .leading, spacing: 8) {
                Text("Enter API Key:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    if showKey {
                        TextField("sk-ant-api03-...", text: $apiKey)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                    } else {
                        SecureField("sk-ant-api03-...", text: $apiKey)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    Button(action: { showKey.toggle() }) {
                        Image(systemName: showKey ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.borderless)
                }
                
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                
                Link(destination: URL(string: "https://console.anthropic.com/")!) {
                    HStack {
                        Image(systemName: "arrow.up.right.square")
                        Text("Get API Key from Anthropic")
                    }
                    .font(.caption)
                }
            }
            
            Divider()
            
            // Buttons
            HStack {
                Button("Later") {
                    onDismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Add Key") {
                    addKey()
                }
                .buttonStyle(.borderedProminent)
                .disabled(apiKey.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 400, height: 280)
    }
    
    private func addKey() {
        guard !apiKey.isEmpty else { return }
        
        if !apiKey.hasPrefix("sk-ant-") {
            errorMessage = "Invalid format. Key should start with 'sk-ant-'"
            return
        }
        
        if apiKey.count < 20 {
            errorMessage = "Key appears too short"
            return
        }
        
        onAddKey(apiKey)
    }
}
