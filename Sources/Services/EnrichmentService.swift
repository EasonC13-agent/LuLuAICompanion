import Foundation

/// Service to enrich connection data with WHOIS, DNS, and geo info
class EnrichmentService {
    
    static let shared = EnrichmentService()
    
    private init() {}
    
    // MARK: - WHOIS Lookup
    
    func fetchWHOIS(for ip: String) async -> String? {
        // Use shell whois command (available on macOS)
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/whois")
        task.arguments = [ip]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            // Extract relevant info from WHOIS
            return parseWHOIS(output)
        } catch {
            print("WHOIS error: \(error)")
            return nil
        }
    }
    
    private func parseWHOIS(_ raw: String) -> String {
        var info: [String] = []
        let lines = raw.components(separatedBy: "\n")
        
        let relevantKeys = ["OrgName", "Organization", "org-name", "netname", "NetName", 
                           "Country", "country", "City", "city", "descr"]
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            for key in relevantKeys {
                if trimmed.lowercased().hasPrefix(key.lowercased() + ":") {
                    let value = trimmed.components(separatedBy: ":").dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces)
                    if !value.isEmpty && !info.contains(where: { $0.contains(value) }) {
                        info.append("\(key): \(value)")
                    }
                }
            }
            
            // Limit to avoid huge output
            if info.count >= 5 { break }
        }
        
        return info.joined(separator: ", ")
    }
    
    // MARK: - DNS Lookup
    
    func fetchDNS(for hostname: String) async -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/dig")
        task.arguments = ["+short", hostname]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            print("DNS error: \(error)")
            return nil
        }
    }
    
    // MARK: - Reverse DNS
    
    func fetchReverseDNS(for ip: String) async -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/dig")
        task.arguments = ["+short", "-x", ip]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            print("Reverse DNS error: \(error)")
            return nil
        }
    }
    
    // MARK: - IP Geolocation (free API)
    
    func fetchGeoLocation(for ip: String) async -> String? {
        guard let url = URL(string: "http://ip-api.com/json/\(ip)?fields=country,city,isp,org") else {
            return nil
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                var parts: [String] = []
                if let city = json["city"] as? String { parts.append(city) }
                if let country = json["country"] as? String { parts.append(country) }
                if let org = json["org"] as? String { parts.append("(\(org))") }
                return parts.joined(separator: ", ")
            }
        } catch {
            print("Geo error: \(error)")
        }
        
        return nil
    }
    
    // MARK: - Full Enrichment
    
    func enrichAlert(_ alert: inout ConnectionAlert) async {
        // Run all lookups concurrently
        async let whois = fetchWHOIS(for: alert.ipAddress)
        async let geo = fetchGeoLocation(for: alert.ipAddress)
        async let reverseDNS = alert.reverseDNS.isEmpty ? fetchReverseDNS(for: alert.ipAddress) : nil
        
        let results = await (whois, geo, reverseDNS)
        
        alert.whoisData = results.0
        alert.geoLocation = results.1
        if let dns = results.2 {
            alert.reverseDNS = dns
        }
    }
}
