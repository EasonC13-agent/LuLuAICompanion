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
        // LuLu alert format: labels and values appear as separate text elements
        // Labels: "pid:", "args:", "path:", "ip address:", "port/protocol:", "(reverse) dns:"
        // Values follow immediately after their labels
        
        print("DEBUG: Extracted \(texts.count) text elements from LuLu alert")
        for (i, t) in texts.enumerated() {
            print("  [\(i)] \(t)")
        }
        
        for (index, text) in texts.enumerated() {
            let trimmed = text.trimmingCharacters(in: .whitespaces)
            let lowercased = trimmed.lowercased()
            
            // Label-based detection: look for label and get next element as value
            if lowercased == "pid:" && index + 1 < texts.count {
                alert.processID = texts[index + 1].trimmingCharacters(in: .whitespaces)
            }
            else if lowercased == "args:" && index + 1 < texts.count {
                alert.processArgs = texts[index + 1].trimmingCharacters(in: .whitespaces)
            }
            else if lowercased == "path:" && index + 1 < texts.count {
                alert.processPath = texts[index + 1].trimmingCharacters(in: .whitespaces)
                // Extract process name from path
                if let name = alert.processPath.components(separatedBy: "/").last {
                    alert.processName = name
                }
            }
            else if lowercased == "ip address:" && index + 1 < texts.count {
                alert.ipAddress = texts[index + 1].trimmingCharacters(in: .whitespaces)
            }
            else if lowercased == "port/protocol:" && index + 1 < texts.count {
                let value = texts[index + 1].trimmingCharacters(in: .whitespaces)
                // Parse "443 (TCP)" format
                let parts = value.components(separatedBy: " ")
                if let port = parts.first {
                    alert.port = port
                }
                alert.proto = value.contains("TCP") ? "TCP" : "UDP"
            }
            else if (lowercased == "(reverse) dns:" || lowercased == "reverse dns:") && index + 1 < texts.count {
                alert.reverseDNS = texts[index + 1].trimmingCharacters(in: .whitespaces)
            }
            // Fallback: IP address pattern without label
            else if trimmed.matches(pattern: "^\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}$") && alert.ipAddress.isEmpty {
                alert.ipAddress = trimmed
            }
            // Fallback: Path pattern without label
            else if trimmed.starts(with: "/") && trimmed.contains("/bin/") && alert.processPath.isEmpty {
                alert.processPath = trimmed
                if let name = trimmed.components(separatedBy: "/").last {
                    alert.processName = name
                }
            }
            // "is connecting to" message - extract process name
            else if trimmed.contains("is connecting to") {
                // The process name is usually the previous text element
                if index > 0 && alert.processName.isEmpty {
                    alert.processName = texts[index - 1].trimmingCharacters(in: .whitespaces)
                }
                if let endpoint = trimmed.components(separatedBy: "is connecting to ").last {
                    let ep = endpoint.trimmingCharacters(in: .whitespaces)
                    if alert.ipAddress.isEmpty && ep.matches(pattern: "\\d{1,3}\\.\\d{1,3}") {
                        alert.ipAddress = ep
                    }
                }
            }
            // Reverse DNS fallback (contains dots, letters, ends with TLD)
            else if trimmed.matches(pattern: "^[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$") && alert.reverseDNS.isEmpty && !trimmed.starts(with: "/") {
                alert.reverseDNS = trimmed
            }
        }
        
        print("DEBUG: Parsed alert - pid:\(alert.processID), args:\(alert.processArgs), path:\(alert.processPath)")
        
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
