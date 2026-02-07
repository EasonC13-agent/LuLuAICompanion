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
        
        // Parse the text elements to extract data - try multiple attributes
        var texts: [String] = []
        var seenTexts = Set<String>()  // Avoid duplicates
        
        for element in elements {
            // Try to get text from various attributes
            let attributes = [
                kAXValueAttribute,
                kAXTitleAttribute,
                kAXDescriptionAttribute,
                kAXHelpAttribute
            ]
            
            for attr in attributes {
                var textValue: CFTypeRef?
                AXUIElementCopyAttributeValue(element, attr as CFString, &textValue)
                if let text = textValue as? String, !text.isEmpty, !seenTexts.contains(text) {
                    texts.append(text)
                    seenTexts.insert(text)
                }
            }
        }
        
        // Parse extracted texts using pattern matching
        // LuLu alert elements come in unpredictable order, so match by content pattern
        
        print("DEBUG: Extracted \(texts.count) text elements from LuLu alert")
        for (i, t) in texts.enumerated() {
            print("  [\(i)] \(t)")
        }
        
        for text in texts {
            let trimmed = text.trimmingCharacters(in: .whitespaces)
            
            // Skip labels (they end with ":")
            if trimmed.hasSuffix(":") { continue }
            
            // PID: 5-6 digit number
            if trimmed.matches(pattern: "^\\d{4,6}$") && alert.processID.isEmpty {
                alert.processID = trimmed
            }
            // IP address: x.x.x.x pattern
            else if trimmed.matches(pattern: "^\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}$") && alert.ipAddress.isEmpty {
                alert.ipAddress = trimmed
            }
            // Port/Protocol: "443 (TCP)" or "80 (UDP)" pattern
            else if trimmed.matches(pattern: "^\\d{1,5} \\((TCP|UDP)\\)$") {
                let parts = trimmed.components(separatedBy: " ")
                if let port = parts.first {
                    alert.port = port
                }
                alert.proto = trimmed.contains("TCP") ? "TCP" : "UDP"
            }
            // Path: starts with / and contains typical path components
            else if trimmed.starts(with: "/") && (trimmed.contains("/bin/") || trimmed.contains("/Applications/") || trimmed.contains("/Library/") || trimmed.contains("/Users/") || trimmed.contains("/usr/") || trimmed.contains("/System/")) {
                alert.processPath = trimmed
                if let name = trimmed.components(separatedBy: "/").last, !name.isEmpty {
                    alert.processName = name
                }
            }
            // URL args: starts with http:// or https://
            else if trimmed.starts(with: "http://") || trimmed.starts(with: "https://") {
                alert.processArgs = trimmed
            }
            // Reverse DNS: hostname pattern (letters, dots, ends with TLD)
            else if trimmed.matches(pattern: "^[a-zA-Z0-9.-]+\\.(com|net|org|io|co|dev|app|cloud|edu|gov|[a-z]{2})\\.*$") && alert.reverseDNS.isEmpty {
                alert.reverseDNS = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "."))
            }
            // Process name: single word, could be "curl", "Safari", etc. (after we've tried other patterns)
            else if !trimmed.isEmpty && !trimmed.contains(" ") && !trimmed.contains("/") && !trimmed.contains(":") && trimmed.count < 50 {
                // Only set if we don't have a process name from path
                if alert.processName.isEmpty && trimmed != "Details & Options" && trimmed != "Process" && trimmed != "Connection" && trimmed != "LuLu Alert" && !trimmed.starts(with: "Time stamp") {
                    alert.processName = trimmed
                }
            }
        }
        
        print("DEBUG: Parsed alert - process:\(alert.processName), pid:\(alert.processID), path:\(alert.processPath), args:\(alert.processArgs), ip:\(alert.ipAddress), port:\(alert.port)")
        
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
