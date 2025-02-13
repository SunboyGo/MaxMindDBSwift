# MaxMindDBSwift

A high-performance Swift wrapper for the MaxMind GeoIP2 database reader. This library provides an elegant Swift interface to [libmaxminddb](https://github.com/maxmind/libmaxminddb), enabling efficient IP geolocation lookups with type-safe access to the MaxMind database format.

## Key Features

- Native Swift implementation with full iOS 12.0+ and macOS 10.15+ support
- Thread-safe concurrent IP lookups with Grand Central Dispatch
- Efficient memory management and resource handling
- Comprehensive error handling with detailed diagnostics
- Seamless integration via Swift Package Manager

## Installation

### Swift Package Manager

Add the package dependency to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/SunboyGo/MaxMindDBSwift.git", from: "1.0.0.44")
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

The `GeoIP2` class implements thread-safe operations using Grand Central Dispatch, allowing concurrent IP lookups from multiple threads without explicit synchronization.

## License

Released under the MIT License. See the [LICENSE](LICENSE) file for the complete license terms.

## Credits

This project builds upon the excellent work of [MaxMind](https://www.maxmind.com/) and their [libmaxminddb](https://github.com/maxmind/libmaxminddb) C library.
