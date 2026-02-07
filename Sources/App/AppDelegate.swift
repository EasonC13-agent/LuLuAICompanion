import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var analysisWindow: NSWindow?
    
    @ObservedObject private var monitor = AccessibilityMonitor.shared
    @ObservedObject private var claudeClient = ClaudeAPIClient.shared
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()
        setupNotifications()
        
        // Auto-start monitoring if accessibility is enabled
        if monitor.checkAccessibilityPermission() {
            monitor.startMonitoring()
        }
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
        popover.contentViewController = NSHostingController(rootView: StatusBarView())
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
        guard var alert = notification.userInfo?["alert"] as? ConnectionAlert else { return }
        
        // Show analysis window
        Task {
            // Enrich the alert with WHOIS/geo data
            await EnrichmentService.shared.enrichAlert(&alert)
            
            // Analyze with Claude
            if claudeClient.hasAPIKey {
                do {
                    let analysis = try await claudeClient.analyzeConnection(alert)
                    await showAnalysisWindow(analysis)
                } catch {
                    print("Analysis error: \(error)")
                    await showAnalysisWindow(AIAnalysis(
                        alert: alert,
                        recommendation: .unknown,
                        summary: "Analysis failed",
                        details: error.localizedDescription
                    ))
                }
            } else {
                // No API key, show basic info
                await showAnalysisWindow(AIAnalysis(
                    alert: alert,
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
        
        // Create new window
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
        
        // Bring app to front
        NSApp.activate(ignoringOtherApps: true)
    }
    
    // MARK: - Menu
    
    private func createMenu() -> NSMenu {
        let menu = NSMenu()
        
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        return menu
    }
    
    @objc private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
}
