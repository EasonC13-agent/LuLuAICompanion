import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var analysisWindow: NSWindow?
    private var welcomeWindow: NSWindow?
    
    private let monitor = AccessibilityMonitor.shared
    private let claudeClient = ClaudeAPIClient.shared
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()
        setupNotifications()
        
        // Check if first launch or needs setup
        if !UserDefaults.standard.bool(forKey: "hasCompletedSetup") || !claudeClient.hasAPIKey {
            showWelcomeWindow()
        } else {
            // Auto-start monitoring if accessibility is enabled
            if monitor.checkAccessibilityPermission() {
                monitor.startMonitoring()
            }
        }
    }
    
    // MARK: - Welcome Window
    
    private func showWelcomeWindow() {
        let welcomeView = WelcomeView(onComplete: { [weak self] in
            self?.welcomeWindow?.close()
            self?.welcomeWindow = nil
            
            // Start monitoring after setup
            if self?.monitor.checkAccessibilityPermission() == true {
                self?.monitor.startMonitoring()
            }
        })
        
        welcomeWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 580),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        welcomeWindow?.title = "Welcome"
        welcomeWindow?.contentView = NSHostingView(rootView: welcomeView)
        welcomeWindow?.center()
        welcomeWindow?.makeKeyAndOrderFront(nil)
        
        NSApp.activate(ignoringOtherApps: true)
    }
    
    // MARK: - Status Bar
    
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "shield.checkered", accessibilityDescription: "LuLu AI")
            button.action = #selector(togglePopover)
        }
        
        // Create popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 400)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: StatusBarView(
            onShowWelcome: { [weak self] in
                self?.popover.performClose(nil)
                self?.showWelcomeWindow()
            }
        ))
    }
    
    @objc private func togglePopover() {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
    }
    
    // MARK: - Alert Notifications
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLuLuAlert(_:)),
            name: .luluAlertDetected,
            object: nil
        )
    }
    
    @objc private func handleLuLuAlert(_ notification: Notification) {
        guard let alert = notification.userInfo?["alert"] as? ConnectionAlert else { return }
        
        Task {
            // Enrich the alert with WHOIS/geo data
            let enrichedAlert = await EnrichmentService.shared.enrichAlert(alert)
            
            // Analyze with Claude
            if claudeClient.hasAPIKey {
                do {
                    let analysis = try await claudeClient.analyzeConnection(enrichedAlert)
                    await showAnalysisWindow(analysis)
                } catch {
                    print("Analysis error: \(error)")
                    await showAnalysisWindow(AIAnalysis(
                        alert: enrichedAlert,
                        recommendation: .unknown,
                        summary: "Analysis failed",
                        details: error.localizedDescription
                    ))
                }
            } else {
                await showAnalysisWindow(AIAnalysis(
                    alert: enrichedAlert,
                    recommendation: .unknown,
                    summary: "No API key configured",
                    details: "Add your Claude API key in settings to enable AI analysis."
                ))
            }
        }
    }
    
    @MainActor
    private func showAnalysisWindow(_ analysis: AIAnalysis) {
        // Close existing window if any
        analysisWindow?.close()
        
        let contentView = AnalysisView(analysis: analysis)
        
        analysisWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 350),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        analysisWindow?.title = "🤖 AI Analysis"
        analysisWindow?.contentView = NSHostingView(rootView: contentView)
        analysisWindow?.center()
        analysisWindow?.level = .floating
        analysisWindow?.makeKeyAndOrderFront(nil)
        
        NSApp.activate(ignoringOtherApps: true)
    }
}
