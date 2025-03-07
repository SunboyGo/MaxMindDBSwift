import Foundation
import CLibMaxMindDB

/// Represents errors that can occur during GeoIP2 operations
public enum GeoIP2Error: Error, LocalizedError {
    /// Failed to open database
    case openFailed(code: Int32)
    /// Failed to lookup IP address
    case lookupFailed(code: Int32, gaiError: Int32?)
    /// Failed to parse data
    case dataParsingFailed(reason: String? = nil)
    /// Invalid database type
    case invalidDatabaseType
    
    public var errorDescription: String? {
        switch self {
        case .invalidDatabaseType:
            return "Invalid database type (requires GeoIP2 format)"
        case .openFailed(let code):
            return "Failed to open database: \(code) - \(mmdbStatusDescription(code))"
        case .lookupFailed(let code, let gaiError):
            if let gaiError = gaiError {
                return "Failed to lookup: mmdb error \(code) (\(mmdbStatusDescription(code))), network error \(gaiError)"
            }
            return "Failed to lookup: error \(code) - \(mmdbStatusDescription(code))"
        case .dataParsingFailed(let reason):
            if let reason = reason {
                return "Failed to parse data: \(reason)"
            }
            return "Failed to parse data"
        }
    }
    
    /// Get description for MMDB status code
    private func mmdbStatusDescription(_ code: Int32) -> String {
        switch code {
        case MMDB_SUCCESS:
            return "Success"
        case MMDB_FILE_OPEN_ERROR:
            return "File open error"
        case MMDB_CORRUPT_SEARCH_TREE_ERROR:
            return "Corrupt search tree"
        case MMDB_INVALID_METADATA_ERROR:
            return "Invalid metadata"
        case MMDB_IO_ERROR:
            return "I/O error"
        case MMDB_OUT_OF_MEMORY_ERROR:
            return "Out of memory"
        case MMDB_UNKNOWN_DATABASE_FORMAT_ERROR:
            return "Unknown database format"
        case MMDB_INVALID_DATA_ERROR:
            return "Invalid data"
        case MMDB_INVALID_LOOKUP_PATH_ERROR:
            return "Invalid lookup path"
        case MMDB_LOOKUP_PATH_DOES_NOT_MATCH_DATA_ERROR:
            return "Lookup path does not match data"
        case MMDB_INVALID_NODE_NUMBER_ERROR:
            return "Invalid node number"
        case MMDB_IPV6_LOOKUP_IN_IPV4_DATABASE_ERROR:
            return "IPv6 lookup in IPv4 database"
        default:
            return "Unknown error"
        }
    }
}

/// Represents the result of a GeoIP2 query
public struct GeoIP2Result {
    /// Raw data dictionary
    public let data: [String: Any]
    
    /// Create a new GeoIP2 result
    /// - Parameter data: Raw data dictionary
    public init(data: [String: Any]) {
        self.data = data
    }
    
    /// Format the result as a readable string, preserving the original data structure
    /// - Parameter indent: Indentation string
    /// - Returns: Formatted string
    public func prettyPrint(indent: String = "") -> String {
        return formatValue(data, indent: indent)
    }
    
    /// Convert the result to a JSON string
    /// - Parameter prettyPrinted: Whether to pretty-print the output
    /// - Returns: JSON string, or nil if conversion fails
    public func toJSON(prettyPrinted: Bool = true) -> String? {
        let options: JSONSerialization.WritingOptions = prettyPrinted ? [.prettyPrinted] : []
        if let jsonData = try? JSONSerialization.data(withJSONObject: data, options: options) {
            return String(data: jsonData, encoding: .utf8)
        }
        return nil
    }
    
    /// Format any value as a string
    /// - Parameters:
    ///   - value: Value to format
    ///   - indent: Indentation string
    /// - Returns: Formatted string
    private func formatValue(_ value: Any, indent: String) -> String {
        switch value {
        case let dict as [String: Any]:
            if dict.isEmpty {
                return "{}"
            }
            
            var result = "{\n"
            // Sort keys to maintain consistent output order
            for (key, val) in dict.sorted(by: { $0.key < $1.key }) {
                let valueStr = formatValue(val, indent: indent + "  ")
                result += "\(indent)  \"\(key)\": \(valueStr),\n"
            }
            // Remove the last comma
            if result.hasSuffix(",\n") {
                result.removeLast(2)
                result += "\n"
            }
            result += "\(indent)}"
            return result
            
        case let array as [Any]:
            if array.isEmpty {
                return "[]"
            }
            
            var result = "[\n"
            for item in array {
                result += "\(indent)  \(formatValue(item, indent: indent + "  ")),\n"
            }
            // Remove the last comma
            if result.hasSuffix(",\n") {
                result.removeLast(2)
                result += "\n"
            }
            result += "\(indent)]"
            return result
            
        case let str as String:
            return "\"\(str)\""
            
        case let num as NSNumber:
            return "\(num)"
            
        case let bool as Bool:
            return bool ? "true" : "false"
            
        case is NSNull:
            return "null"
            
        default:
            return "\(value)"
        }
    }
}

/// GeoIP2 database access class
public final class GeoIP2 {
    /// Internal MMDB pointer
    private let mmdb: UnsafeMutablePointer<MMDB_s>
    /// Queue for thread safety
    private let queue = DispatchQueue(label: "com.geoip.queue", attributes: .concurrent)
    /// String cache to reduce memory usage
    private let stringCache = NSCache<NSString, NSString>()
    
    /// Initialize a GeoIP2 instance
    /// - Parameter databasePath: Path to the database file
    /// - Throws: GeoIP2Error if opening the database fails
    public init(databasePath: String) throws {
        // Directly allocate MMDB structure memory
        let mmdbPtr = UnsafeMutablePointer<MMDB_s>.allocate(capacity: 1)
        mmdbPtr.pointee = MMDB_s()
        
        // Open the database
        let status = MMDB_open(databasePath, UInt32(MMDB_MODE_MMAP), mmdbPtr)
        
        // Check open status
        guard status == MMDB_SUCCESS else {
            mmdbPtr.deallocate()
            throw GeoIP2Error.openFailed(code: status)
        }
        
        self.mmdb = mmdbPtr
        
        // Configure string cache
        stringCache.countLimit = 1000 // Limit cache entries
    }
    
    /// Synchronously lookup IP address information
    /// - Parameter ip: IP address string
    /// - Returns: Query result
    /// - Throws: GeoIP2Error if lookup fails
    public func lookup(ip: String) throws -> GeoIP2Result {
        try queue.sync {
            try ip.withCString { cString in
                var gai_error: Int32 = 0
                var mmdb_error: Int32 = 0
                
                // Execute query
                let result = MMDB_lookup_string(mmdb, cString, &gai_error, &mmdb_error)
                
                // Check MMDB error
                if mmdb_error != MMDB_SUCCESS {
                    throw GeoIP2Error.lookupFailed(code: mmdb_error, gaiError: nil)
                }
                
                // Check network error
                if gai_error != 0 {
                    throw GeoIP2Error.lookupFailed(code: mmdb_error, gaiError: gai_error)
                }
                
                // If no entry is found, return empty result
                guard result.found_entry else {
                    return GeoIP2Result(data: [:])
                }
                
                // Parse complete data
                var entry = result.entry
                let fullData = try parseFullData(entry: &entry)
                
                return GeoIP2Result(data: fullData)
            }
        }
    }
    
    /// Asynchronously lookup IP address information
    /// - Parameters:
    ///   - ip: IP address string
    ///   - completion: Completion callback, returns result or error
    public func lookupAsync(ip: String, completion: @escaping (Result<GeoIP2Result, Error>) -> Void) {
        queue.async {
            do {
                let result = try self.lookup(ip: ip)
                completion(.success(result))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    /// Parse complete data
    /// - Parameter entry: MMDB entry
    /// - Returns: Parsed data dictionary
    /// - Throws: GeoIP2Error if parsing fails
    private func parseFullData(entry: inout MMDB_entry_s) throws -> [String: Any] {
        var entryList: UnsafeMutablePointer<MMDB_entry_data_list_s>?
        let status = MMDB_get_entry_data_list(&entry, &entryList)
        
        // Ensure resources are released
        defer {
            if let list = entryList {
                MMDB_free_entry_data_list(list)
            }
        }
        
        // Check status
        guard status == MMDB_SUCCESS, let list = entryList else {
            throw GeoIP2Error.dataParsingFailed(reason: "Failed to get entry data list, status: \(status)")
        }
        
        return try parseEntryDataList(entryList: list)
    }
    
    /// Parse entry data list
    /// - Parameter entryList: MMDB entry data list
    /// - Returns: Parsed data dictionary
    /// - Throws: GeoIP2Error if parsing fails
    private func parseEntryDataList(entryList: UnsafeMutablePointer<MMDB_entry_data_list_s>) throws -> [String: Any] {
        // Get the first entry
        let firstEntry = entryList.pointee
        
        // Ensure top-level data is MAP type
        guard firstEntry.entry_data.type == UInt32(MMDB_DATA_TYPE_MAP) else {
            throw GeoIP2Error.dataParsingFailed(reason: "Top level data is not a MAP")
        }
        
        // Parse top-level MAP
        return try parseMapStructure(entryList: entryList)
    }
    
    /// Parse MAP structure
    /// - Parameter entryList: Data list pointer
    /// - Returns: Parsed dictionary
    /// - Throws: GeoIP2Error if parsing fails
    private func parseMapStructure(entryList: UnsafeMutablePointer<MMDB_entry_data_list_s>) throws -> [String: Any] {
        let mapData = entryList.pointee.entry_data
        let size = Int(mapData.data_size)
        var result = Dictionary<String, Any>(minimumCapacity: size)
        
        // Move to the first key
        var current = entryList.pointee.next
        
        // Parse key-value pairs in the MAP
        for _ in 0..<size {
            // Ensure there is a key
            guard let keyPtr = current else {
                break
            }
            
            // Parse key
            let keyData = keyPtr.pointee.entry_data
            guard keyData.type == UInt32(MMDB_DATA_TYPE_UTF8_STRING) else {
                throw GeoIP2Error.dataParsingFailed(reason: "Invalid key type in MAP")
            }
            
            // Get key string
            guard let keyStr = try? parseString(data: keyData) else {
                throw GeoIP2Error.dataParsingFailed(reason: "Failed to parse key string")
            }
            
            // Move to value
            current = keyPtr.pointee.next
            guard let valuePtr = current else {
                break
            }
            
            // Parse value
            let valueData = valuePtr.pointee.entry_data
            let value: Any
            
            switch valueData.type {
            case UInt32(MMDB_DATA_TYPE_MAP):
                // Recursively parse nested MAP
                value = try parseMapStructure(entryList: valuePtr)
                // Move current to position after the nested MAP is parsed
                current = findNextEntryAfterStructure(startingFrom: valuePtr)
            case UInt32(MMDB_DATA_TYPE_ARRAY):
                // Parse array
                value = try parseArrayStructure(entryList: valuePtr)
                // Move current to position after the nested array is parsed
                current = findNextEntryAfterStructure(startingFrom: valuePtr)
            case UInt32(MMDB_DATA_TYPE_UTF8_STRING):
                value = try parseString(data: valueData)
                current = valuePtr.pointee.next
            case UInt32(MMDB_DATA_TYPE_DOUBLE):
                value = valueData.double_value
                current = valuePtr.pointee.next
            case UInt32(MMDB_DATA_TYPE_UINT16):
                value = valueData.uint16
                current = valuePtr.pointee.next
            case UInt32(MMDB_DATA_TYPE_UINT32):
                value = valueData.uint32
                current = valuePtr.pointee.next
            case UInt32(MMDB_DATA_TYPE_INT32):
                value = valueData.int32
                current = valuePtr.pointee.next
            case UInt32(MMDB_DATA_TYPE_UINT64):
                value = valueData.uint64
                current = valuePtr.pointee.next
            case UInt32(MMDB_DATA_TYPE_BOOLEAN):
                value = valueData.boolean
                current = valuePtr.pointee.next
            default:
                throw GeoIP2Error.dataParsingFailed(reason: "Unknown data type: \(valueData.type)")
            }
            
            // Store key-value pair
            result[keyStr] = value
        }
        
        return result
    }
    
    /// Parse array structure
    /// - Parameter entryList: Data list pointer
    /// - Returns: Parsed array
    /// - Throws: GeoIP2Error if parsing fails
    private func parseArrayStructure(entryList: UnsafeMutablePointer<MMDB_entry_data_list_s>) throws -> [Any] {
        let arrayData = entryList.pointee.entry_data
        let size = Int(arrayData.data_size)
        var result = [Any]()
        result.reserveCapacity(size)
        
        // Move to the first element
        var current = entryList.pointee.next
        
        // Parse array elements
        for _ in 0..<size {
            guard let itemPtr = current else {
                break
            }
            
            // Parse element value
            let itemData = itemPtr.pointee.entry_data
            let value: Any
            
            switch itemData.type {
            case UInt32(MMDB_DATA_TYPE_MAP):
                // Recursively parse nested MAP
                value = try parseMapStructure(entryList: itemPtr)
                // Move current to position after the nested MAP is parsed
                current = findNextEntryAfterStructure(startingFrom: itemPtr)
            case UInt32(MMDB_DATA_TYPE_ARRAY):
                // Recursively parse nested array
                value = try parseArrayStructure(entryList: itemPtr)
                // Move current to position after the nested array is parsed
                current = findNextEntryAfterStructure(startingFrom: itemPtr)
            case UInt32(MMDB_DATA_TYPE_UTF8_STRING):
                value = try parseString(data: itemData)
                current = itemPtr.pointee.next
            case UInt32(MMDB_DATA_TYPE_DOUBLE):
                value = itemData.double_value
                current = itemPtr.pointee.next
            case UInt32(MMDB_DATA_TYPE_UINT16):
                value = itemData.uint16
                current = itemPtr.pointee.next
            case UInt32(MMDB_DATA_TYPE_UINT32):
                value = itemData.uint32
                current = itemPtr.pointee.next
            case UInt32(MMDB_DATA_TYPE_INT32):
                value = itemData.int32
                current = itemPtr.pointee.next
            case UInt32(MMDB_DATA_TYPE_UINT64):
                value = itemData.uint64
                current = itemPtr.pointee.next
            case UInt32(MMDB_DATA_TYPE_BOOLEAN):
                value = itemData.boolean
                current = itemPtr.pointee.next
            default:
                throw GeoIP2Error.dataParsingFailed(reason: "Unknown data type: \(itemData.type)")
            }
            
            // Add to result array
            result.append(value)
        }
        
        return result
    }
    
    /// Find the next entry after parsing a structure
    /// - Parameter startingFrom: Starting entry
    /// - Returns: Pointer to the next entry, or nil if there are no more entries
    private func findNextEntryAfterStructure(startingFrom entry: UnsafeMutablePointer<MMDB_entry_data_list_s>) -> UnsafeMutablePointer<MMDB_entry_data_list_s>? {
        let entryData = entry.pointee.entry_data
        var count = 0
        var current = entry.pointee.next
        
        switch entryData.type {
        case UInt32(MMDB_DATA_TYPE_MAP):
            count = Int(entryData.data_size)
            // Each key-value pair in a MAP requires 2 entries (key and value)
            for _ in 0..<count {
                // Skip key
                current = current?.pointee.next
                // If value is a composite structure (MAP or ARRAY), need to recursively skip
                if let valuePtr = current {
                    let valueType = valuePtr.pointee.entry_data.type
                    if valueType == UInt32(MMDB_DATA_TYPE_MAP) || valueType == UInt32(MMDB_DATA_TYPE_ARRAY) {
                        current = findNextEntryAfterStructure(startingFrom: valuePtr)
                    } else {
                        current = valuePtr.pointee.next
                    }
                }
            }
        case UInt32(MMDB_DATA_TYPE_ARRAY):
            count = Int(entryData.data_size)
            // Each element in the array
            for _ in 0..<count {
                if let itemPtr = current {
                    let itemType = itemPtr.pointee.entry_data.type
                    if itemType == UInt32(MMDB_DATA_TYPE_MAP) || itemType == UInt32(MMDB_DATA_TYPE_ARRAY) {
                        current = findNextEntryAfterStructure(startingFrom: itemPtr)
                    } else {
                        current = itemPtr.pointee.next
                    }
                }
            }
        default:
            // For simple types, the next entry is simply the next one
            current = entry.pointee.next
        }
        
        return current
    }
    
    /// Parse string type data
    /// - Parameter data: MMDB entry data
    /// - Returns: Parsed string
    /// - Throws: GeoIP2Error if parsing fails
    private func parseString(data: MMDB_entry_data_s) throws -> String {
        guard let str = data.utf8_string else {
            return ""
        }
        
        let dataSize = Int(data.data_size)
        
        // For short strings, try to get from cache
        if dataSize < 100 {
            // Create UInt8 buffer
            let uint8Ptr = UnsafeRawPointer(str).assumingMemoryBound(to: UInt8.self)
            let buffer = UnsafeBufferPointer(start: uint8Ptr, count: dataSize)
            
            if let stringData = Data(buffer: buffer) as NSData? {
                let hashValue = stringData.hashValue
                let hashKey = NSString(format: "%d", hashValue)
                
                // Check cache
                if let cachedString = stringCache.object(forKey: hashKey) {
                    return cachedString as String
                }
                
                // Create new string and cache it
                if let string = String(bytes: buffer, encoding: .utf8) {
                    let nsString = string as NSString
                    stringCache.setObject(nsString, forKey: hashKey)
                    return string
                }
            }
        }
        
        // For long strings or cache misses, create directly
        let uint8Ptr = UnsafeRawPointer(str).assumingMemoryBound(to: UInt8.self)
        guard let string = String(bytes: UnsafeBufferPointer(start: uint8Ptr, count: dataSize),
                                encoding: .utf8) else {
            return ""
        }
        return string
    }
    
    /// Get database metadata
    /// - Returns: Database metadata dictionary
    /// - Throws: GeoIP2Error if retrieval fails
    public func metadata() throws -> [String: Any] {
        return try queue.sync {
            var entryList: UnsafeMutablePointer<MMDB_entry_data_list_s>?
            let status = MMDB_get_metadata_as_entry_data_list(mmdb, &entryList)
            
            // Ensure resources are released
            defer {
                if let list = entryList {
                    MMDB_free_entry_data_list(list)
                }
            }
            
            guard status == MMDB_SUCCESS, let list = entryList else {
                throw GeoIP2Error.dataParsingFailed(reason: "Failed to get metadata")
            }
            
            return try parseEntryDataList(entryList: list)
        }
    }
    
    /// Return data directly as a JSON string
    /// - Parameter ip: IP address
    /// - Returns: Raw JSON string
    /// - Throws: Error if lookup or conversion fails
    public func lookupJSON(ip: String, prettyPrinted: Bool = true) throws -> String {
        let result = try lookup(ip: ip)
        if let json = result.toJSON(prettyPrinted: prettyPrinted) {
            return json
        }
        throw GeoIP2Error.dataParsingFailed(reason: "Failed to convert result to JSON")
    }
    
    /// Get raw data as JSON representation
    /// - Parameter ip: IP address
    /// - Returns: Raw data JSON string
    /// - Throws: Error if lookup fails
    public func getRawDataJSON(ip: String) throws -> String {
        return try queue.sync {
            try ip.withCString { cString in
                var gai_error: Int32 = 0
                var mmdb_error: Int32 = 0
                
                // Execute query
                let result = MMDB_lookup_string(mmdb, cString, &gai_error, &mmdb_error)
                
                // Check errors
                if mmdb_error != MMDB_SUCCESS {
                    throw GeoIP2Error.lookupFailed(code: mmdb_error, gaiError: nil)
                }
                if gai_error != 0 {
                    throw GeoIP2Error.lookupFailed(code: mmdb_error, gaiError: gai_error)
                }
                
                // If no entry is found, return empty result
                guard result.found_entry else {
                    return "{}"
                }
                
                var entry = result.entry
                var entryList: UnsafeMutablePointer<MMDB_entry_data_list_s>?
                let status = MMDB_get_entry_data_list(&entry, &entryList)
                
                // Ensure resources are released
                defer {
                    if let list = entryList {
                        MMDB_free_entry_data_list(list)
                    }
                }
                
                guard status == MMDB_SUCCESS, let list = entryList else {
                    throw GeoIP2Error.dataParsingFailed(reason: "Failed to get entry data list")
                }
                
                // Parse data
                let data = try parseEntryDataList(entryList: list)
                
                // Convert to JSON
                let options: JSONSerialization.WritingOptions = [.prettyPrinted, .sortedKeys]
                guard let jsonData = try? JSONSerialization.data(withJSONObject: data, options: options),
                      let jsonString = String(data: jsonData, encoding: .utf8) else {
                    throw GeoIP2Error.dataParsingFailed(reason: "Failed to convert data to JSON")
                }
                
                return jsonString
            }
        }
    }
    
    /// Parse MAP type data
    /// - Parameter entryList: Data list pointer
    /// - Returns: Parsed dictionary
    /// - Throws: GeoIP2Error if parsing fails
    private func parseMap(entryList: UnsafeMutablePointer<MMDB_entry_data_list_s>) throws -> [String: Any] {
        // This method has been replaced by parseMapStructure, kept for backward compatibility
        return try parseMapStructure(entryList: entryList)
    }
    
    /// Parse array type data
    /// - Parameter entryList: Data list pointer
    /// - Returns: Parsed array
    /// - Throws: GeoIP2Error if parsing fails
    private func parseArray(entryList: UnsafeMutablePointer<MMDB_entry_data_list_s>) throws -> [Any] {
        // This method has been replaced by parseArrayStructure, kept for backward compatibility
        return try parseArrayStructure(entryList: entryList)
    }
    
    /// Release resources
    deinit {
        MMDB_close(mmdb)
        mmdb.deallocate()
    }
}

