import Foundation

/// Data extracted from a LuLu alert window
struct ConnectionAlert: Identifiable {
    let id = UUID()
    let timestamp: Date
    
    // Process info (best-effort parsed)
    var processName: String
    var processPath: String
    var processID: String
    var processArgs: String
    
    // Connection info (best-effort parsed)
    var ipAddress: String
    var port: String
    var proto: String  // TCP/UDP
    var reverseDNS: String
    
    // RAW text elements from LuLu alert (for Claude to analyze)
    var rawTexts: [String] = []
    
    // Enrichment data (fetched async)
    var whoisData: String?
    var geoLocation: String?
    var threatIntel: String?
    
    init(processName: String = "",
         processPath: String = "",
         processID: String = "",
         processArgs: String = "",
         ipAddress: String = "",
         port: String = "",
         proto: String = "TCP",
         reverseDNS: String = "",
         rawTexts: [String] = []) {
        self.timestamp = Date()
        self.processName = processName
        self.processPath = processPath
        self.processID = processID
        self.processArgs = processArgs
        self.ipAddress = ipAddress
        self.port = port
        self.proto = proto
        self.reverseDNS = reverseDNS
        self.rawTexts = rawTexts
    }
    
    /// Format for Claude API prompt - includes raw texts for AI to parse
    var promptDescription: String {
        var desc = """
        Connection Alert from LuLu Firewall:
        
        Raw UI Elements (in order extracted from alert window):
        """
        
        for (i, text) in rawTexts.enumerated() {
            desc += "\n  [\(i)] \(text)"
        }
        
        desc += "\n\nEnriched Data:"
        if let whois = whoisData {
            desc += "\n- WHOIS: \(whois)"
        }
        if let geo = geoLocation {
            desc += "\n- Location: \(geo)"
        }
        
        return desc
    }
}
