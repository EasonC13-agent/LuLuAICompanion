import Cocoa
import ApplicationServices

/// Monitors for LuLu alert windows using Accessibility API
class AccessibilityMonitor: ObservableObject {
    @Published var isMonitoring = false
    @Published var lastAlert: ConnectionAlert?
    @Published var accessibilityEnabled = false
    
    private var observer: AXObserver?
    private var timer: Timer?
    
    static let shared = AccessibilityMonitor()
    
    private init() {
        checkAccessibilityPermission()
    }
    
    // MARK: - Permission Check
    
    func checkAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        DispatchQueue.main.async {
            self.accessibilityEnabled = trusted
        }
        return trusted
    }
    
    // MARK: - Monitoring
    
    func startMonitoring() {
        guard checkAccessibilityPermission() else {
            print("Accessibility permission not granted")
            return
        }
        
        isMonitoring = true
        
        // Poll for LuLu windows every 500ms
        // (More reliable than AXObserver for cross-app monitoring)
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkForLuLuAlert()
        }
        
        print("Started monitoring for LuLu alerts")
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        isMonitoring = false
        print("Stopped monitoring")
    }
    
    // MARK: - Window Detection
    
    private func checkForLuLuAlert() {
        // Find LuLu process
        let runningApps = NSWorkspace.shared.runningApplications
        guard let luluApp = runningApps.first(where: { 
            $0.bundleIdentifier == "com.objective-see.lulu.app" ||
            $0.localizedName == "LuLu"
        }) else {
            return
        }
        
        let pid = luluApp.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)
        
        // Get windows
        var windowsValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue)
        
        guard result == .success, let windows = windowsValue as? [AXUIElement] else {
            return
        }
        
        // Check each window for "LuLu Alert" title
        for window in windows {
            var titleValue: CFTypeRef?
            AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleValue)
            
            if let title = titleValue as? String, title.contains("LuLu Alert") {
                extractAlertData(from: window)
                return
            }
        }
    }
    
    // MARK: - Data Extraction
    
    private func extractAlertData(from window: AXUIElement) {
        var alert = ConnectionAlert()
        
        // Get all UI elements recursively
        let elements = getAllElements(from: window)
        
        // Parse the text elements to extract data
        var texts: [String] = []
        for element in elements {
            var roleValue: CFTypeRef?
            AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleValue)
            
            if let role = roleValue as? String, 
               role == kAXStaticTextRole as String || role == kAXTextFieldRole as String {
                var textValue: CFTypeRef?
                AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &textValue)
                if let text = textValue as? String, !text.isEmpty {
                    texts.append(text)
                }
            }
        }
        
        // Parse extracted texts
        // LuLu alert format based on source code:
        // - Process name is prominent
        // - "is connecting to [endpoint]"
        // - Details section has: pid, args, path, ip address, port/protocol, reverse dns
        
        for (index, text) in texts.enumerated() {
            let lowercased = text.lowercased()
            
            // IP address pattern
            if text.matches(pattern: "^\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}$") {
                alert.ipAddress = text
            }
            // Port/Protocol (e.g., "443 (TCP)")
            else if text.contains("(TCP)") || text.contains("(UDP)") {
                let parts = text.components(separatedBy: " ")
                if let port = parts.first {
                    alert.port = port
                }
                alert.proto = text.contains("TCP") ? "TCP" : "UDP"
            }
            // Process ID
            else if lowercased.contains("pid:") || text.matches(pattern: "^\\d{3,6}$") {
                if let match = text.matches(pattern: "\\d+") {
                    alert.processID = match
                }
            }
            // Path detection
            else if text.starts(with: "/") && text.contains("/") {
                if text.contains(".app") || text.contains("/bin/") || text.contains("/Library/") {
                    alert.processPath = text
                    // Extract process name from path
                    if let name = text.components(separatedBy: "/").last {
                        alert.processName = name
                    }
                }
            }
            // "is connecting to" message
            else if text.contains("is connecting to") {
                if let endpoint = text.components(separatedBy: "is connecting to ").last {
                    if alert.ipAddress.isEmpty {
                        alert.ipAddress = endpoint.trimmingCharacters(in: .whitespaces)
                    }
                }
            }
            // Reverse DNS (usually contains dots and letters)
            else if text.contains(".") && text.matches(pattern: "^[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$") {
                alert.reverseDNS = text
            }
        }
        
        // Also try to get window title for process name
        var titleValue: CFTypeRef?
        AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleValue)
        
        // Only trigger if we have meaningful data and it's different from last alert
        if !alert.ipAddress.isEmpty && alert.ipAddress != lastAlert?.ipAddress {
            print("Detected LuLu Alert: \(alert.processName) -> \(alert.ipAddress):\(alert.port)")
            DispatchQueue.main.async {
                self.lastAlert = alert
            }
            
            // Post notification for other parts of app
            NotificationCenter.default.post(
                name: .luluAlertDetected,
                object: nil,
                userInfo: ["alert": alert]
            )
        }
    }
    
    private func getAllElements(from element: AXUIElement) -> [AXUIElement] {
        var result: [AXUIElement] = [element]
        
        var childrenValue: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenValue)
        
        if let children = childrenValue as? [AXUIElement] {
            for child in children {
                result.append(contentsOf: getAllElements(from: child))
            }
        }
        
        return result
    }
}

// MARK: - Notification Extension

extension Notification.Name {
    static let luluAlertDetected = Notification.Name("luluAlertDetected")
}

// MARK: - String Extension for Regex

extension String {
    func matches(pattern: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        let range = NSRange(self.startIndex..., in: self)
        return regex.firstMatch(in: self, options: [], range: range) != nil
    }
    
    func matches(pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(self.startIndex..., in: self)
        if let match = regex.firstMatch(in: self, options: [], range: range) {
            return String(self[Range(match.range, in: self)!])
        }
        return nil
    }
}
