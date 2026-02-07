import Foundation

/// Data extracted from a LuLu alert window
struct ConnectionAlert: Identifiable {
    let id = UUID()
    let timestamp: Date
    
    // Process info
    var processName: String
    var processPath: String
    var processID: String
    var processArgs: String
    
    // Connection info
    var ipAddress: String
    var port: String
    var proto: String  // TCP/UDP
    var reverseDNS: String
    
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
         reverseDNS: String = "") {
        self.timestamp = Date()
        self.processName = processName
        self.processPath = processPath
        self.processID = processID
        self.processArgs = processArgs
        self.ipAddress = ipAddress
        self.port = port
        self.proto = proto
        self.reverseDNS = reverseDNS
    }
    
    /// Format for Claude API prompt
    var promptDescription: String {
        """
        Connection Alert Details:
        - Process: \(processName) (PID: \(processID))
        - Path: \(processPath)
        - Arguments: \(processArgs.isEmpty ? "none" : processArgs)
        - Destination IP: \(ipAddress)
        - Port/Protocol: \(port) (\(proto))
        - Reverse DNS: \(reverseDNS.isEmpty ? "N/A" : reverseDNS)
        \(whoisData.map { "- WHOIS: \($0)" } ?? "")
        \(geoLocation.map { "- Location: \($0)" } ?? "")
        """
    }
}
