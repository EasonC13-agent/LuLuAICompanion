import Cocoa

// Handle CLI commands before starting the app
let args = CommandLine.arguments

if args.count > 1 {
    let command = args[1]
    
    switch command {
    case "--add-key", "-a":
        if args.count > 2 {
            let key = args[2]
            if key.hasPrefix("sk-ant-") {
                let slot = ClaudeAPIClient.shared.nextAvailableSlot()
                ClaudeAPIClient.shared.addAPIKey(key, slot: slot)
                print("✓ API key added to slot \(slot)")
                exit(0)
            } else {
                print("✗ Invalid key format. Key should start with 'sk-ant-'")
                exit(1)
            }
        } else {
            print("Usage: LuLuAICompanion --add-key <api-key>")
            exit(1)
        }
        
    case "--remove-key", "-r":
        let slot = args.count > 2 ? Int(args[2]) ?? 0 : 0
        ClaudeAPIClient.shared.removeAPIKey(slot: slot)
        print("✓ API key removed from slot \(slot)")
        exit(0)
        
    case "--list-keys", "-l":
        let keys = ClaudeAPIClient.shared.listKeys()
        if keys.isEmpty || keys.allSatisfy({ !$0.hasKey }) {
            print("No API keys configured")
        } else {
            print("Configured API keys:")
            for (slot, hasKey, prefix) in keys {
                if hasKey {
                    print("  Slot \(slot): \(prefix ?? "***")")
                }
            }
        }
        
        // Also check environment
        if ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] != nil {
            print("  [env] ANTHROPIC_API_KEY is set")
        }
        exit(0)
        
    case "--status", "-s":
        let keyCount = ClaudeAPIClient.shared.apiKeys.count
        print("LuLu AI Companion")
        print("  API keys: \(keyCount)")
        print("  Has key: \(ClaudeAPIClient.shared.hasAPIKey ? "yes" : "no")")
        exit(0)
        
    case "--help", "-h":
        print("""
        LuLu AI Companion - AI-powered firewall analysis
        
        Usage: LuLuAICompanion [command]
        
        Commands:
          --add-key, -a <key>     Add an API key
          --remove-key, -r [slot] Remove an API key (default slot 0)
          --list-keys, -l         List configured API keys
          --status, -s            Show status
          --help, -h              Show this help
        
        Without arguments, starts the menu bar app.
        
        Examples:
          LuLuAICompanion --add-key sk-ant-api03-xxx
          LuLuAICompanion --list-keys
        """)
        exit(0)
        
    default:
        print("Unknown command: \(command)")
        print("Use --help for usage information")
        exit(1)
    }
}

// No CLI args - start the app normally
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
