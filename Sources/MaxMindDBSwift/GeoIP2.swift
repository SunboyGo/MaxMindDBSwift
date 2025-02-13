import Foundation
import CLibMaxMindDB

public struct GeoIP2Error: Error {
    public let message: String
    public let code: Int32
    
    init(message: String, code: Int32 = 0) {
        self.message = message
        self.code = code
    }
}

public final class GeoIP2 {
    private var mmdb: UnsafeMutablePointer<MMDB_s>?
    private let queue = DispatchQueue(label: "com.geoip.queue", attributes: .concurrent)
    
    public init(databasePath: String) throws {
        var mmdb = MMDB_s()
        let status = MMDB_open(databasePath, UInt32(MMDB_MODE_MMAP), &mmdb)
        
        guard status == MMDB_SUCCESS else {
            throw GeoIP2Error(message: String(cString: MMDB_strerror(status)), code: status)
        }
        
        self.mmdb = UnsafeMutablePointer<MMDB_s>.allocate(capacity: 1)
        self.mmdb?.pointee = mmdb
    }
    
    deinit {
        if let mmdb = mmdb {
            MMDB_close(mmdb.pointee)
            mmdb.deallocate()
        }
    }
    
    public func lookup(_ ipAddress: String) throws -> [String: Any] {
        return try queue.sync {
            guard let mmdb = mmdb else {
                throw GeoIP2Error(message: "Database not initialized")
            }
            
            var gai_error: Int32 = 0
            var error: Int32 = 0
            var result = MMDB_lookup_result_s()
            
            result = MMDB_lookup_string(&mmdb.pointee, ipAddress, &gai_error, &error)
            
            if gai_error != 0 {
                throw GeoIP2Error(message: String(cString: gai_strerror(gai_error)), code: gai_error)
            }
            
            if error != MMDB_SUCCESS {
                throw GeoIP2Error(message: String(cString: MMDB_strerror(error)), code: error)
            }
            
            if !result.found_entry {
                return [:]
            }
            
            var entry_data_list: UnsafeMutablePointer<MMDB_entry_data_list_s>?
            let status = MMDB_get_entry_data_list(&result.entry, &entry_data_list)
            
            guard status == MMDB_SUCCESS else {
                throw GeoIP2Error(message: String(cString: MMDB_strerror(status)), code: status)
            }
            
            defer {
                MMDB_free_entry_data_list(entry_data_list)
            }
            
            return try parseEntryData(entry_data_list)
        }
    }
    
    private func parseEntryData(_ entry_data: UnsafeMutablePointer<MMDB_entry_data_list_s>?) throws -> [String: Any] {
        var current = entry_data
        var result: [String: Any] = [:]
        
        while let entry = current {
            let key = String(cString: entry.pointee.entry_data.utf8_string)
            current = entry.pointee.next
            
            guard let next = current else { break }
            
            switch Int32(next.pointee.entry_data.type) {
            case MMDB_DATA_TYPE_MAP:
                let count = next.pointee.entry_data.data_size
                current = next.pointee.next
                result[key] = try parseMap(current, count: count)
            case MMDB_DATA_TYPE_ARRAY:
                let count = next.pointee.entry_data.data_size
                current = next.pointee.next
                result[key] = try parseArray(current, count: count)
            case MMDB_DATA_TYPE_UTF8_STRING:
                result[key] = String(cString: next.pointee.entry_data.utf8_string)
                current = next.pointee.next
            case MMDB_DATA_TYPE_UINT32:
                result[key] = UInt32(next.pointee.entry_data.uint32)
                current = next.pointee.next
            case MMDB_DATA_TYPE_DOUBLE:
                result[key] = next.pointee.entry_data.double_value
                current = next.pointee.next
            case MMDB_DATA_TYPE_BOOLEAN:
                result[key] = next.pointee.entry_data.boolean
                current = next.pointee.next
            default:
                current = next.pointee.next
            }
        }
        
        return result
    }
    
    private func parseMap(_ entry_data: UnsafeMutablePointer<MMDB_entry_data_list_s>?, count: UInt32) throws -> [String: Any] {
        var current = entry_data
        var result: [String: Any] = [:]
        
        for _ in 0..<count {
            guard let entry = current else { break }
            
            let key = String(cString: entry.pointee.entry_data.utf8_string)
            current = entry.pointee.next
            
            guard let next = current else { break }
            
            switch Int32(next.pointee.entry_data.type) {
            case MMDB_DATA_TYPE_MAP:
                let subCount = next.pointee.entry_data.data_size
                current = next.pointee.next
                result[key] = try parseMap(current, count: subCount)
            case MMDB_DATA_TYPE_ARRAY:
                let subCount = next.pointee.entry_data.data_size
                current = next.pointee.next
                result[key] = try parseArray(current, count: subCount)
            case MMDB_DATA_TYPE_UTF8_STRING:
                result[key] = String(cString: next.pointee.entry_data.utf8_string)
                current = next.pointee.next
            case MMDB_DATA_TYPE_UINT32:
                result[key] = UInt32(next.pointee.entry_data.uint32)
                current = next.pointee.next
            case MMDB_DATA_TYPE_DOUBLE:
                result[key] = next.pointee.entry_data.double_value
                current = next.pointee.next
            case MMDB_DATA_TYPE_BOOLEAN:
                result[key] = next.pointee.entry_data.boolean
                current = next.pointee.next
            default:
                current = next.pointee.next
            }
        }
        
        return result
    }
    
    private func parseArray(_ entry_data: UnsafeMutablePointer<MMDB_entry_data_list_s>?, count: UInt32) throws -> [Any] {
        var current = entry_data
        var result: [Any] = []
        
        for _ in 0..<count {
            guard let next = current else { break }
            
            switch Int32(next.pointee.entry_data.type) {
            case MMDB_DATA_TYPE_MAP:
                let subCount = next.pointee.entry_data.data_size
                current = next.pointee.next
                result.append(try parseMap(current, count: subCount))
            case MMDB_DATA_TYPE_ARRAY:
                let subCount = next.pointee.entry_data.data_size
                current = next.pointee.next
                result.append(try parseArray(current, count: subCount))
            case MMDB_DATA_TYPE_UTF8_STRING:
                result.append(String(cString: next.pointee.entry_data.utf8_string))
                current = next.pointee.next
            case MMDB_DATA_TYPE_UINT32:
                result.append(UInt32(next.pointee.entry_data.uint32))
                current = next.pointee.next
            case MMDB_DATA_TYPE_DOUBLE:
                result.append(next.pointee.entry_data.double_value)
                current = next.pointee.next
            case MMDB_DATA_TYPE_BOOLEAN:
                result.append(next.pointee.entry_data.boolean)
                current = next.pointee.next
            default:
                current = next.pointee.next
            }
        }
        
        return result
    }
}
