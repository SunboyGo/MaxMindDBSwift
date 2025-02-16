# MaxMindDBSwift

A high-performance Swift wrapper for MaxMind's GeoIP2 database. This library provides an elegant Swift interface to [libmaxminddb](https://github.com/maxmind/libmaxminddb), offering efficient IP geolocation lookups with type-safe access to MaxMind's MMDB format.

## Key Features

- High-performance Swift implementation with iOS 12.0+ and macOS 10.15+ support
- Optimized concurrent IP lookups using Grand Central Dispatch
- Zero-overhead memory management with direct C interop
- Type-safe API with comprehensive error handling
- Simple integration via Swift Package Manager

## Installation

### Swift Package Manager

Add the package dependency to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/SunboyGo/MaxMindDBSwift.git", from: "1.0.71")
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
      geoname_id: 6252001
      iso_code: "US"
      names: {
        en: "United States"
        zh-CN: "美国"
        de: "USA"
        fr: "États Unis"
        ja: "アメリカ"
        pt-BR: "EUA"
        es: "Estados Unidos"
        ru: "США"
      }
      continent: {
        geoname_id: 6255149
        code: "NA"
        names: {
          en: "North America"
          es: "Norteamérica"
          de: "Nordamerika"
          zh-CN: "北美洲"
          fr: "Amérique du Nord"
          pt-BR: "América do Norte"
          ru: "Северная Америка"
          ja: "北アメリカ"
        }
      }
    }
    */
    
    // Extract specific geolocation data
    if let names = result.data["names"] as? [String: String],
       let countryName = names["en"] {
        print("Country: \(countryName)")     // Output: "United States"
    }
    
    if let iso_code = result.data["iso_code"] {
        print("ISO Code: \(iso_code)")       // Output: "US"
    }
    
    if let continent = result.data["continent"] as? [String: Any],
       let names = continent["names"] as? [String: String],
       let continentName = names["en"] {
        print("Continent: \(continentName)") // Output: "North America"
    }
} catch {
    print("Lookup failed: \(error)")
}
```

## Concurrency Support

The `GeoIP2` class implements an efficient concurrent read model using a Grand Central Dispatch concurrent queue. The implementation enables multiple threads to perform IP lookups simultaneously while maintaining thread safety. The underlying database access is handled through memory-mapped files (MMAP) by libmaxminddb, providing efficient I/O performance for database reads.

## Acknowledgments

Special thanks to [MaxMind](https://www.maxmind.com/) for creating and maintaining the excellent [libmaxminddb](https://github.com/maxmind/libmaxminddb) C library, which forms the foundation of this project.

## License

Released under the MIT License. See the [LICENSE](LICENSE) file for the complete license terms.
