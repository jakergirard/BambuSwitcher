import Foundation
import AppKit
import Security

class ConfigurationManager: ObservableObject {
    @Published var configurations: [Configuration] = []
    private let fileManager = FileManager.default
    
    init() {
        loadConfigurations()
    }
    
    private func loadConfigurations() {
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            print("Error: Could not find Application Support directory")
            return
        }
        
        let configsDirectory = appSupport.appendingPathComponent("BambuStudio_Configs")
        print("Looking for configurations in: \(configsDirectory.path)")
        
        do {
            try fileManager.createDirectory(at: configsDirectory, withIntermediateDirectories: true)
            let contents = try fileManager.contentsOfDirectory(at: configsDirectory, includingPropertiesForKeys: nil)
            configurations = contents
                .filter { $0.hasDirectoryPath }
                .map { Configuration(name: $0.lastPathComponent, path: $0) }
            
            print("Found \(configurations.count) configurations:")
            configurations.forEach { config in
                print("- \(config.name) at \(config.path.path)")
            }
        } catch {
            print("Error loading configurations: \(error)")
        }
    }
    
    private func clearExistingData() throws {
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first,
              let library = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first else {
            throw ConfigError.appSupportNotFound
        }
        
        // Clear Application Support
        let bambuStudioConfig = appSupport.appendingPathComponent("BambuStudio")
        if fileManager.fileExists(atPath: bambuStudioConfig.path) {
            try fileManager.removeItem(at: bambuStudioConfig)
        }
        
        // Clear Preferences
        let preferencesPath = library.appendingPathComponent("Preferences/com.bambulab.bambu-studio.plist")
        if fileManager.fileExists(atPath: preferencesPath.path) {
            try fileManager.removeItem(at: preferencesPath)
        }
        
        // Clear Cache
        let cachePath = library.appendingPathComponent("Caches/com.bambulab.bambu-studio")
        if fileManager.fileExists(atPath: cachePath.path) {
            try fileManager.removeItem(at: cachePath)
        }
        
        // Clear HTTPStorages (cookies and web storage)
        let binaryCookiesPath = library.appendingPathComponent("HTTPStorages/com.bambulab.bambu-studio.binarycookies")
        let httpStoragePath = library.appendingPathComponent("HTTPStorages/com.bambulab.bambu-studio")
        if fileManager.fileExists(atPath: binaryCookiesPath.path) {
            try fileManager.removeItem(at: binaryCookiesPath)
        }
        if fileManager.fileExists(atPath: httpStoragePath.path) {
            try fileManager.removeItem(at: httpStoragePath)
        }
        
        // Clear WebKit data
        let webKitPath = library.appendingPathComponent("WebKit/com.bambulab.bambu-studio")
        if fileManager.fileExists(atPath: webKitPath.path) {
            try fileManager.removeItem(at: webKitPath)
        }
        
        // Clear Saved Application State
        let savedStatePath = library.appendingPathComponent("Saved Application State/com.bambulab.bambu-studio.savedState")
        if fileManager.fileExists(atPath: savedStatePath.path) {
            try fileManager.removeItem(at: savedStatePath)
        }
        
        // Clear defaults
        UserDefaults.standard.removePersistentDomain(forName: "com.bambulab.bambu-studio")
        
        // Kill any running Bambu processes
        let task = Process()
        task.launchPath = "/usr/bin/pkill"
        task.arguments = ["-f", "BambuStudio"]
        try? task.run()
        task.waitUntilExit()
    }
    
    private func copyPreferencesAndCache(from config: Configuration) throws {
        guard let library = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first else {
            throw ConfigError.appSupportNotFound
        }
        
        // Copy Preferences if they exist
        let sourcePrefs = config.path.appendingPathComponent("com.bambulab.bambu-studio.plist")
        let targetPrefs = library.appendingPathComponent("Preferences/com.bambulab.bambu-studio.plist")
        if fileManager.fileExists(atPath: sourcePrefs.path) {
            if fileManager.fileExists(atPath: targetPrefs.path) {
                try fileManager.removeItem(at: targetPrefs)
            }
            try fileManager.copyItem(at: sourcePrefs, to: targetPrefs)
        }
        
        // Copy Cache if it exists
        let sourceCache = config.path.appendingPathComponent("Cache")
        let targetCache = library.appendingPathComponent("Caches/com.bambulab.bambu-studio")
        if fileManager.fileExists(atPath: sourceCache.path) {
            if fileManager.fileExists(atPath: targetCache.path) {
                try fileManager.removeItem(at: targetCache)
            }
            try fileManager.copyItem(at: sourceCache, to: targetCache)
        }
        
        // Copy HTTPStorages
        let sourceCookies = config.path.appendingPathComponent("binarycookies")
        let targetCookies = library.appendingPathComponent("HTTPStorages/com.bambulab.bambu-studio.binarycookies")
        if fileManager.fileExists(atPath: sourceCookies.path) {
            if fileManager.fileExists(atPath: targetCookies.path) {
                try fileManager.removeItem(at: targetCookies)
            }
            try fileManager.copyItem(at: sourceCookies, to: targetCookies)
        }
        
        let sourceStorage = config.path.appendingPathComponent("HTTPStorage")
        let targetStorage = library.appendingPathComponent("HTTPStorages/com.bambulab.bambu-studio")
        if fileManager.fileExists(atPath: sourceStorage.path) {
            if fileManager.fileExists(atPath: targetStorage.path) {
                try fileManager.removeItem(at: targetStorage)
            }
            try fileManager.copyItem(at: sourceStorage, to: targetStorage)
        }
        
        // Copy WebKit data
        let sourceWebKit = config.path.appendingPathComponent("WebKit")
        let targetWebKit = library.appendingPathComponent("WebKit/com.bambulab.bambu-studio")
        if fileManager.fileExists(atPath: sourceWebKit.path) {
            if fileManager.fileExists(atPath: targetWebKit.path) {
                try fileManager.removeItem(at: targetWebKit)
            }
            try fileManager.copyItem(at: sourceWebKit, to: targetWebKit)
        }
        
        // Restore defaults
        let defaultsPath = config.path.appendingPathComponent("defaults.json")
        if fileManager.fileExists(atPath: defaultsPath.path),
           let defaultsData = try? Data(contentsOf: defaultsPath),
           let defaults = try? JSONSerialization.jsonObject(with: defaultsData) as? [String: Any],
           let userDefaults = UserDefaults(suiteName: "com.bambulab.bambu-studio") {
            for (key, value) in defaults {
                userDefaults.set(value, forKey: key)
            }
            userDefaults.synchronize()
        }
    }
    
    func switchToConfiguration(_ config: Configuration) throws {
        print("Switching to configuration: \(config.name)")
        print("Source: \(config.path.path)")
        
        // Clear all existing data
        try clearExistingData()
        
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw ConfigError.appSupportNotFound
        }
        
        let bambuStudioConfig = appSupport.appendingPathComponent("BambuStudio")
        print("Target: \(bambuStudioConfig.path)")
        
        // Create the target directory
        try fileManager.createDirectory(at: bambuStudioConfig, withIntermediateDirectories: true)
        
        // Copy all contents from source to target
        let enumerator = fileManager.enumerator(at: config.path, includingPropertiesForKeys: nil)
        while let sourcePath = enumerator?.nextObject() as? URL {
            // Skip preferences and cache directories as they're handled separately
            if sourcePath.lastPathComponent == "com.bambulab.bambu-studio.plist" ||
               sourcePath.lastPathComponent == "Cache" {
                continue
            }
            
            let relativePath = sourcePath.lastPathComponent
            let targetPath = bambuStudioConfig.appendingPathComponent(relativePath)
            
            print("Copying: \(relativePath)")
            if fileManager.fileExists(atPath: targetPath.path) {
                try fileManager.removeItem(at: targetPath)
            }
            try fileManager.copyItem(at: sourcePath, to: targetPath)
        }
        
        // Copy preferences and cache
        try copyPreferencesAndCache(from: config)
        
        print("Configuration switch completed successfully")
    }
    
    func launchBambuStudio() {
        let bambuStudioURL = URL(fileURLWithPath: "/Applications/BambuStudio.app")
        print("Launching Bambu Studio from: \(bambuStudioURL.path)")
        
        // Add a small delay to ensure cleanup is complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSWorkspace.shared.openApplication(at: bambuStudioURL,
                                            configuration: NSWorkspace.OpenConfiguration()) { running, error in
                if let error = error {
                    print("Error launching Bambu Studio: \(error)")
                } else {
                    print("Bambu Studio launched successfully")
                }
            }
        }
    }
    
    func saveCurrentConfiguration(name: String) throws {
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first,
              let library = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first else {
            throw ConfigError.appSupportNotFound
        }
        
        // Target directory
        let configsDirectory = appSupport.appendingPathComponent("BambuStudio_Configs")
        let newConfigPath = configsDirectory.appendingPathComponent(name)
        
        // If configuration already exists, remove it first
        if fileManager.fileExists(atPath: newConfigPath.path) {
            try fileManager.removeItem(at: newConfigPath)
        }
        
        // Create the new configuration directory
        try fileManager.createDirectory(at: newConfigPath, withIntermediateDirectories: true)
        
        // Source paths
        let bambuStudioConfig = appSupport.appendingPathComponent("BambuStudio")
        let preferencesPath = library.appendingPathComponent("Preferences/com.bambulab.bambu-studio.plist")
        let cachePath = library.appendingPathComponent("Caches/com.bambulab.bambu-studio")
        let binaryCookiesPath = library.appendingPathComponent("HTTPStorages/com.bambulab.bambu-studio.binarycookies")
        let httpStoragePath = library.appendingPathComponent("HTTPStorages/com.bambulab.bambu-studio")
        let webKitPath = library.appendingPathComponent("WebKit/com.bambulab.bambu-studio")
        
        // Copy BambuStudio directory contents
        if fileManager.fileExists(atPath: bambuStudioConfig.path) {
            let enumerator = fileManager.enumerator(at: bambuStudioConfig, includingPropertiesForKeys: nil)
            while let sourcePath = enumerator?.nextObject() as? URL {
                let relativePath = sourcePath.path.replacingOccurrences(of: bambuStudioConfig.path, with: "")
                if !relativePath.isEmpty {
                    let targetPath = newConfigPath.appendingPathComponent(relativePath)
                    
                    if sourcePath.hasDirectoryPath {
                        try? fileManager.createDirectory(at: targetPath, withIntermediateDirectories: true)
                    } else {
                        try? fileManager.removeItem(at: targetPath)
                        try fileManager.copyItem(at: sourcePath, to: targetPath)
                    }
                }
            }
        }
        
        // Copy preferences file
        if fileManager.fileExists(atPath: preferencesPath.path) {
            let targetPrefs = newConfigPath.appendingPathComponent("com.bambulab.bambu-studio.plist")
            try? fileManager.removeItem(at: targetPrefs)
            try fileManager.copyItem(at: preferencesPath, to: targetPrefs)
        }
        
        // Copy cache directory
        if fileManager.fileExists(atPath: cachePath.path) {
            let targetCache = newConfigPath.appendingPathComponent("Cache")
            try? fileManager.removeItem(at: targetCache)
            try fileManager.copyItem(at: cachePath, to: targetCache)
        }
        
        // Copy HTTPStorages
        if fileManager.fileExists(atPath: binaryCookiesPath.path) {
            let targetCookies = newConfigPath.appendingPathComponent("binarycookies")
            try? fileManager.removeItem(at: targetCookies)
            try fileManager.copyItem(at: binaryCookiesPath, to: targetCookies)
        }
        if fileManager.fileExists(atPath: httpStoragePath.path) {
            let targetStorage = newConfigPath.appendingPathComponent("HTTPStorage")
            try? fileManager.removeItem(at: targetStorage)
            try fileManager.copyItem(at: httpStoragePath, to: targetStorage)
        }
        
        // Copy WebKit data
        if fileManager.fileExists(atPath: webKitPath.path) {
            let targetWebKit = newConfigPath.appendingPathComponent("WebKit")
            try? fileManager.removeItem(at: targetWebKit)
            try fileManager.copyItem(at: webKitPath, to: targetWebKit)
        }
        
        // Save defaults (handling binary data)
        if let defaults = UserDefaults(suiteName: "com.bambulab.bambu-studio")?.dictionaryRepresentation() {
            var serializableDefaults: [String: Any] = [:]
            for (key, value) in defaults {
                if let data = value as? Data {
                    // Skip binary data
                    continue
                } else if JSONSerialization.isValidJSONObject([key: value]) {
                    serializableDefaults[key] = value
                }
            }
            
            if !serializableDefaults.isEmpty {
                let defaultsData = try JSONSerialization.data(withJSONObject: serializableDefaults)
                let defaultsPath = newConfigPath.appendingPathComponent("defaults.json")
                try defaultsData.write(to: defaultsPath)
            }
        }
        
        // Reload configurations on main thread
        DispatchQueue.main.async { [weak self] in
            self?.loadConfigurations()
        }
    }
    
    func deleteConfiguration(_ config: Configuration) throws {
        if fileManager.fileExists(atPath: config.path.path) {
            try fileManager.removeItem(at: config.path)
            
            // Reload configurations on main thread
            DispatchQueue.main.async { [weak self] in
                self?.loadConfigurations()
            }
        }
    }
    
    func hasConfigurationWithName(_ name: String) -> Bool {
        return configurations.contains { $0.name.lowercased() == name.lowercased() }
    }
}

enum ConfigError: Error {
    case appSupportNotFound
} 
