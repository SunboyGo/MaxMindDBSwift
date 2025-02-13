import Foundation
import CLibMaxMindDB

public enum GeoIP2Error: Error, LocalizedError {
    case openFailed(code: Int32)
    case lookupFailed(code: Int32, gaiError: Int32?)
    case dataParsingFailed
    case invalidDatabaseType
    
    public var errorDescription: String? {
        switch self {
        case .invalidDatabaseType:
            return "Invalid database type (requires GeoIP2 format)"
        case .openFailed(let code):
            return "Failed to open database: \(code)"
        case .lookupFailed(let code, let gaiError):
            if let gaiError = gaiError {
                return "Failed to lookup: mmdb error \(code), network error \(gaiError)"
            }
            return "Failed to lookup: error \(code)"
        case .dataParsingFailed:
            return "Failed to parse data"
        }
    }
}

public struct GeoIP2Result {
    public let data: [String: Any]
    
    public func prettyPrint(indent: String = "") -> String {
        return formatValue(data, indent: indent)
    }
    
    private func formatValue(_ value: Any, indent: String) -> String {
        switch value {
        case let dict as [String: Any]:
            var result = "{\n"
            for (key, val) in dict {
                result += "\(indent)  \(key): \(formatValue(val, indent: indent + "  "))\n"
            }
            result += "\(indent)}"
            return result
        case let array as [Any]:
            var result = "[\n"
            for item in array {
                result += "\(indent)  \(formatValue(item, indent: indent + "  "))\n"
            }
            result += "\(indent)]"
            return result
        case let str as String:
            return "\"\(str)\""
        default:
            return "\(value)"
        }
    }
}

public final class GeoIP2 {
    private let mmdb: UnsafeMutablePointer<MMDB_s>
    private let queue = DispatchQueue(label: "com.geoip.queue", attributes: .concurrent)
    
    public init(databasePath: String) throws {
        var mmdb = MMDB_s()
        let status = MMDB_open(databasePath, UInt32(MMDB_MODE_MMAP), &mmdb)
        
        guard status == MMDB_SUCCESS else {
            throw GeoIP2Error.openFailed(code: status)
        }
        
        let mmdbPtr = UnsafeMutablePointer<MMDB_s>.allocate(capacity: 1)
        mmdbPtr.initialize(to: mmdb)
        self.mmdb = mmdbPtr
    }
    
    public func lookup(ip: String) throws -> GeoIP2Result {
        try queue.sync {
            try ip.withCString { cString in
                var gai_error: Int32 = 0
                var mmdb_error: Int32 = 0
                
                let result = MMDB_lookup_string(mmdb, cString, &gai_error, &mmdb_error)
                
                if mmdb_error != MMDB_SUCCESS {
                    throw GeoIP2Error.lookupFailed(code: mmdb_error, gaiError: nil)
                }
                
                if gai_error != 0 {
                    throw GeoIP2Error.lookupFailed(code: mmdb_error, gaiError: gai_error)
                }
                
                guard result.found_entry else {
                    return GeoIP2Result(data: [:])
                }
                
                var entry = result.entry
                let fullData = try parseFullData(entry: &entry)
                return GeoIP2Result(data: fullData)
            }
        }
    }
    
    private func parseFullData(entry: inout MMDB_entry_s) throws -> [String: Any] {
        var entryList: UnsafeMutablePointer<MMDB_entry_data_list_s>?
        let status = MMDB_get_entry_data_list(&entry, &entryList)
        defer {
            if let list = entryList {
                MMDB_free_entry_data_list(list)
            }
        }
        
        guard status == MMDB_SUCCESS, let list = entryList else {
            throw GeoIP2Error.dataParsingFailed
        }
        
        return try parseEntryDataList(entryList: list)
    }
    
    private func parseEntryDataList(entryList: UnsafeMutablePointer<MMDB_entry_data_list_s>) throws -> [String: Any] {
        var result = Dictionary<String, Any>(minimumCapacity: 16)
        var current: UnsafeMutablePointer<MMDB_entry_data_list_s>? = entryList
        
        while let list = current?.pointee {
            let entryData = list.entry_data
            
            if entryData.type == UInt32(MMDB_DATA_TYPE_MAP) {
                let size = Int(entryData.data_size)
                var next = list.next
                
                for _ in 0..<size {
                    guard let keyData = next?.pointee.entry_data else { break }
                    let key = try parseValue(data: keyData) as? String ?? ""
                    
                    next = next?.pointee.next
                    guard let valueData = next?.pointee.entry_data else { break }
                    
                    result[key] = try parseValue(data: valueData)
                    
                    next = next?.pointee.next
                }
                
                current = next
                continue
            }
            
            current = list.next
        }
        
        return result
    }
    
    private func parseValue(data: MMDB_entry_data_s) throws -> Any {
        switch data.type {
        case UInt32(MMDB_DATA_TYPE_UTF8_STRING):
            guard let str = data.utf8_string,
                  let string = String(bytesNoCopy: UnsafeMutableRawPointer(mutating: str),
                                    length: Int(data.data_size),
                                    encoding: .utf8,
                                    freeWhenDone: false) else {
                return ""
            }
            return string
            
        case UInt32(MMDB_DATA_TYPE_DOUBLE):
            return data.double_value
        case UInt32(MMDB_DATA_TYPE_UINT16):
            return data.uint16
        case UInt32(MMDB_DATA_TYPE_UINT32):
            return data.uint32
        case UInt32(MMDB_DATA_TYPE_INT32):
            return data.int32
        case UInt32(MMDB_DATA_TYPE_UINT64):
            return data.uint64
        case UInt32(MMDB_DATA_TYPE_BOOLEAN):
            return data.boolean
            
        case UInt32(MMDB_DATA_TYPE_MAP):
            var entry = MMDB_entry_s()
            entry.mmdb = UnsafePointer(mmdb)
            entry.offset = data.offset
            
            var entryList: UnsafeMutablePointer<MMDB_entry_data_list_s>?
            let status = MMDB_get_entry_data_list(&entry, &entryList)
            defer {
                if let list = entryList {
                    MMDB_free_entry_data_list(list)
                }
            }
            guard status == MMDB_SUCCESS, let list = entryList else {
                throw GeoIP2Error.dataParsingFailed
            }
            return try parseEntryDataList(entryList: list)
            
        case UInt32(MMDB_DATA_TYPE_ARRAY):
            var array = [Any]()
            var entry = MMDB_entry_s()
            entry.mmdb = UnsafePointer(mmdb)
            entry.offset = data.offset
            
            var currentList: UnsafeMutablePointer<MMDB_entry_data_list_s>?
            let status = MMDB_get_entry_data_list(&entry, &currentList)
            guard status == MMDB_SUCCESS else {
                throw GeoIP2Error.dataParsingFailed
            }
            
            for _ in 0..<Int(data.data_size) {
                guard let list = currentList else { break }
                let value = try parseValue(data: list.pointee.entry_data)
                array.append(value)
                currentList = list.pointee.next
            }
            return array
            
        default:
            throw GeoIP2Error.dataParsingFailed
        }
    }
    
    deinit {
        MMDB_close(mmdb)
        mmdb.deallocate()
    }
}
