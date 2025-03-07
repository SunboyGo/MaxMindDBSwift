# MaxMindDBSwift

A high-performance Swift wrapper for MaxMind's GeoIP2 database. This library provides an elegant Swift interface to [libmaxminddb](https://github.com/maxmind/libmaxminddb), offering efficient IP geolocation lookups with type-safe access to MaxMind's MMDB format.

## Key Features

- High-performance Swift implementation with iOS 12.0+ and macOS 10.15+ support
- Thread-safe concurrent IP lookups using Grand Central Dispatch
- Zero-overhead memory management with direct C interop
- Memory-efficient string caching for better performance
- Type-safe API with comprehensive error handling
- Simple integration via Swift Package Manager

## Installation

### Swift Package Manager

Add the package dependency to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/SunboyGo/MaxMindDBSwift.git", from: "1.1.0")
]
```

Alternatively, in Xcode:
1. Navigate to File > Add Packages...
2. Input the repository URL: `https://github.com/SunboyGo/MaxMindDBSwift.git`
3. Select "Up to Next Major Version" for version rules

## Quick Start

```swift
import MaxMindDB

do {
    // Load the GeoIP database from your app bundle
    guard let fileURL = Bundle.main.url(forResource: "GeoLite2-Country", withExtension: "mmdb") else {
        print("GeoLite2-Country.mmdb not found in the app bundle")
        return
    }
    
    // Initialize the GeoIP2 database reader
    let geoIP = try GeoIP2(databasePath: fileURL.path)
    
    // Perform an IP lookup
    let result = try geoIP.lookup(ip: "8.8.8.8")
    
    // Display the complete lookup result
    print(result.prettyPrint())
    
    /* Example output:
    {
      "continent": {
        "code": "NA",
        "geoname_id": 6255149,
        "names": {
          "de": "Nordamerika",
          "en": "North America",
          "es": "Norteamérica",
          "fr": "Amérique du Nord",
          "ja": "北アメリカ",
          "pt-BR": "América do Norte",
          "ru": "Северная Америка",
          "zh-CN": "北美洲"
        }
      },
      "country": {
        "geoname_id": 6252001,
        "iso_code": "US",
        "names": {
          "de": "USA",
          "en": "United States",
          "es": "Estados Unidos",
          "fr": "États-Unis",
          "ja": "アメリカ合衆国",
          "pt-BR": "Estados Unidos",
          "ru": "США",
          "zh-CN": "美国"
        }
      },
      "registered_country": {
        "geoname_id": 6252001,
        "iso_code": "US",
        "names": {
          "de": "USA",
          "en": "United States",
          "es": "Estados Unidos",
          "fr": "États-Unis",
          "ja": "アメリカ合衆国",
          "pt-BR": "Estados Unidos",
          "ru": "США",
          "zh-CN": "美国"
        }
      }
    }
    */
    
    // Extract specific geolocation data
    if let country = result.data["country"] as? [String: Any],
       let names = country["names"] as? [String: String],
       let countryName = names["en"] {
        print("Country: \(countryName)")     // Output: "United States"
    }
    
    if let country = result.data["country"] as? [String: Any],
       let isoCode = country["iso_code"] as? String {
        print("ISO Code: \(isoCode)")       // Output: "US"
    }
    
    if let continent = result.data["continent"] as? [String: Any],
       let continentCode = continent["code"] as? String {
        print("Continent: \(continentCode)") // Output: "NA"
    }
    
    // Get result as JSON string
    if let jsonString = result.toJSON(prettyPrinted: true) {
        print("JSON Result:\n\(jsonString)")
    }
    
    // Alternatively, get JSON directly
    let jsonResult = try geoIP.lookupJSON(ip: "8.8.8.8")
    print("Direct JSON Result:\n\(jsonResult)")
    
    // For raw data with different formatting
    let rawJSON = try geoIP.getRawDataJSON(ip: "8.8.8.8")
    print("Raw JSON:\n\(rawJSON)")
    
} catch {
    print("Lookup failed: \(error.localizedDescription)")
}
```

## Asynchronous Usage

The library also supports asynchronous lookups for non-blocking operations:

```swift
geoIP.lookupAsync(ip: "8.8.8.8") { result in
    switch result {
    case .success(let geoIPResult):
        print("Async lookup successful: \(geoIPResult.prettyPrint())")
    case .failure(let error):
        print("Async lookup failed: \(error.localizedDescription)")
    }
}
```

## Database Metadata

You can access database metadata to get information about the database:

```swift
do {
    let metadata = try geoIP.metadata()
    print("Database description: \(metadata["description"] ?? "Not available")")
    print("Database build date: \(metadata["build_epoch"] ?? "Not available")")
} catch {
    print("Failed to get metadata: \(error.localizedDescription)")
}
```

## Thread Safety and Performance

The `GeoIP2` class implements an efficient concurrent read model using a Grand Central Dispatch concurrent queue. This allows multiple threads to perform IP lookups simultaneously while maintaining thread safety. 

Performance optimizations include:
- Memory-mapped database access (MMAP) using libmaxminddb for efficient I/O
- String caching for frequently accessed values to reduce memory allocations
- Direct pointer manipulation to minimize overhead

## Acknowledgments

Special thanks to [MaxMind](https://www.maxmind.com/) for creating and maintaining the excellent [libmaxminddb](https://github.com/maxmind/libmaxminddb) C library, which forms the foundation of this project.

## License

Released under the MIT License. See the [LICENSE](LICENSE) file for the complete license terms.
