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
        
        // Kill any running Bambu processes first
        let task = Process()
        task.launchPath = "/usr/bin/pkill"
        task.arguments = ["-f", "BambuStudio"]
        try? task.run()
        task.waitUntilExit()
        
        // Clear Application Support
        let bambuStudioConfig = appSupport.appendingPathComponent("BambuStudio")
        if fileManager.fileExists(atPath: bambuStudioConfig.path) {
            try fileManager.removeItem(at: bambuStudioConfig)
        }
        
        // Clear all Preferences
        let preferencesPath = library.appendingPathComponent("Preferences/com.bambulab.bambu-studio.plist")
        if fileManager.fileExists(atPath: preferencesPath.path) {
            try fileManager.removeItem(at: preferencesPath)
        }
        
        // Clear all Caches
        let cachePaths = [
            library.appendingPathComponent("Caches/com.bambulab.bambu-studio"),
            library.appendingPathComponent("Caches/BambuStudio"),
            appSupport.appendingPathComponent("Caches/com.bambulab.bambu-studio"),
            appSupport.appendingPathComponent("Caches/BambuStudio")
        ]
        
        for cachePath in cachePaths {
            if fileManager.fileExists(atPath: cachePath.path) {
                try fileManager.removeItem(at: cachePath)
            }
        }
        
        // Clear HTTPStorages (cookies and web storage)
        let httpStoragePaths = [
            library.appendingPathComponent("HTTPStorages/com.bambulab.bambu-studio.binarycookies"),
            library.appendingPathComponent("HTTPStorages/com.bambulab.bambu-studio"),
            library.appendingPathComponent("HTTPStorages/BambuStudio.binarycookies"),
            library.appendingPathComponent("HTTPStorages/BambuStudio")
        ]
        
        for storagePath in httpStoragePaths {
            if fileManager.fileExists(atPath: storagePath.path) {
                try fileManager.removeItem(at: storagePath)
            }
        }
        
        // Clear WebKit data
        let webKitPaths = [
            library.appendingPathComponent("WebKit/com.bambulab.bambu-studio"),
            library.appendingPathComponent("WebKit/BambuStudio")
        ]
        
        for webKitPath in webKitPaths {
            if fileManager.fileExists(atPath: webKitPath.path) {
                try fileManager.removeItem(at: webKitPath)
            }
        }
        
        // Clear Saved Application State
        let savedStatePaths = [
            library.appendingPathComponent("Saved Application State/com.bambulab.bambu-studio.savedState"),
            library.appendingPathComponent("Saved Application State/BambuStudio.savedState")
        ]
        
        for statePath in savedStatePaths {
            if fileManager.fileExists(atPath: statePath.path) {
                try fileManager.removeItem(at: statePath)
            }
        }
        
        // Clear all defaults
        UserDefaults.standard.removePersistentDomain(forName: "com.bambulab.bambu-studio")
        UserDefaults.standard.removePersistentDomain(forName: "BambuStudio")
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
        UserDefaults.standard.synchronize()
        
        // Additional cleanup
        try? fileManager.removeItem(at: library.appendingPathComponent("Application Support/BambuStudio"))
        try? fileManager.removeItem(at: library.appendingPathComponent("Preferences/BambuStudio.plist"))
        
        // Force sync to ensure all changes are written
        let syncTask = Process()
        syncTask.launchPath = "/usr/bin/sync"
        try? syncTask.run()
        syncTask.waitUntilExit()
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
        
        // Kill any running Bambu processes first
        let killTask = Process()
        killTask.launchPath = "/usr/bin/pkill"
        killTask.arguments = ["-f", "BambuStudio"]
        try? killTask.run()
        killTask.waitUntilExit()
        
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw ConfigError.appSupportNotFound
        }
        
        let bambuStudioConfig = appSupport.appendingPathComponent("BambuStudio")
        
        // Remove existing BambuStudio directory if it exists
        if fileManager.fileExists(atPath: bambuStudioConfig.path) {
            try fileManager.removeItem(at: bambuStudioConfig)
        }
        
        // Create fresh BambuStudio directory
        try fileManager.createDirectory(at: bambuStudioConfig, withIntermediateDirectories: true)
        
        // Copy all contents from source to target
        let enumerator = fileManager.enumerator(at: config.path, includingPropertiesForKeys: nil)
        while let sourcePath = enumerator?.nextObject() as? URL {
            let relativePath = sourcePath.path.replacingOccurrences(of: config.path.path, with: "")
            if !relativePath.isEmpty {
                let targetPath = bambuStudioConfig.appendingPathComponent(relativePath)
                
                if sourcePath.hasDirectoryPath {
                    try? fileManager.createDirectory(at: targetPath, withIntermediateDirectories: true)
                } else {
                    try? fileManager.removeItem(at: targetPath)
                    try fileManager.copyItem(at: sourcePath, to: targetPath)
                }
            }
        }
        
        // Force sync to ensure all changes are written
        let syncTask = Process()
        syncTask.launchPath = "/usr/bin/sync"
        try? syncTask.run()
        syncTask.waitUntilExit()
        
        print("Configuration switch completed successfully")
    }
    
    func launchBambuStudio() {
        let bambuStudioURL = URL(fileURLWithPath: "/Applications/BambuStudio.app")
        print("Launching Bambu Studio from: \(bambuStudioURL.path)")
        
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        
        NSWorkspace.shared.openApplication(at: bambuStudioURL,
                                         configuration: configuration) { running, error in
            if let error = error {
                print("Error launching Bambu Studio: \(error)")
            } else {
                print("Bambu Studio launched successfully")
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
