import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var configManager = ConfigurationManager()
    @State private var selectedConfig: Configuration?
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var isShowingSaveDialog = false
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Bambu Studio Configurations")
                .font(.title)
                .padding(.top, 20)
            
            // Configuration List
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if configManager.configurations.isEmpty {
                        Text("No configurations found")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 40)
                    } else {
                        ForEach(configManager.configurations) { config in
                            HStack {
                                Text(config.name)
                                    .padding(.horizontal)
                                Spacer()
                                if selectedConfig?.id == config.id {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                        .padding(.trailing)
                                }
                            }
                            .contentShape(Rectangle())
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(selectedConfig?.id == config.id ? Color.accentColor.opacity(0.1) : Color.clear)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: selectedConfig?.id == config.id ? 1 : 0)
                            )
                            .onTapGesture {
                                selectedConfig = config
                            }
                        }
                    }
                }
                .padding(.all, 16)
            }
            .frame(height: 250)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
            .padding(.horizontal)
            
            // Action Buttons
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    Button(action: { isShowingSaveDialog = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Save Current Config")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    
                    Button(action: {
                        guard selectedConfig != nil else { return }
                        showDeleteConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "trash.fill")
                            Text("Delete")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(selectedConfig == nil)
                }
                
                Button(action: launchWithSelectedConfig) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Launch Bambu Studio")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedConfig == nil)
            }
            .padding([.horizontal, .bottom])
        }
        .frame(minWidth: 500, minHeight: 450)
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
        .alert("Delete Configuration", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteSelectedConfiguration()
            }
        } message: {
            Text("Are you sure you want to delete '\(selectedConfig?.name ?? "")'?")
        }
        .sheet(isPresented: $isShowingSaveDialog, onDismiss: nil) {
            SaveConfigurationView(isPresented: $isShowingSaveDialog, onSave: saveConfiguration)
                .interactiveDismissDisabled()
        }
    }
    
    private func saveConfiguration(name: String) {
        do {
            try configManager.saveCurrentConfiguration(name: name)
        } catch {
            errorMessage = "Failed to save configuration: \(error.localizedDescription)"
            showError = true
        }
    }
    
    private func deleteSelectedConfiguration() {
        guard let config = selectedConfig else { return }
        do {
            try configManager.deleteConfiguration(config)
            selectedConfig = nil
        } catch {
            errorMessage = "Failed to delete configuration: \(error.localizedDescription)"
            showError = true
        }
    }
    
    private func launchWithSelectedConfig() {
        guard let config = selectedConfig else { return }
        
        do {
            try configManager.switchToConfiguration(config)
            configManager.launchBambuStudio()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                NSApplication.shared.terminate(nil)
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

struct SaveConfigurationView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var isPresented: Bool
    let onSave: (String) -> Void
    @State private var configName = ""
    @State private var showError = false
    @FocusState private var isTextFieldFocused: Bool
    @StateObject private var configManager = ConfigurationManager()
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Save Current Configuration")
                .font(.title)
                .padding(.top, 20)
            
            VStack(spacing: 16) {
                TextField("Configuration Name", text: $configName)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 300)
                    .focused($isTextFieldFocused)
                    .onSubmit {
                        saveIfValid()
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
            }
            .padding(.horizontal)
            
            HStack(spacing: 12) {
                Button(action: { dismiss() }) {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                        Text("Cancel")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
                .buttonStyle(.borderedProminent)
                .tint(.gray)
                .keyboardShortcut(.escape)
                
                Button(action: { saveIfValid() }) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Save")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(configName.isEmpty)
                .keyboardShortcut(.return)
            }
            .padding([.horizontal, .bottom])
        }
        .frame(width: 500, height: 250)
        .onAppear {
            isTextFieldFocused = true
        }
        .alert("Configuration Already Exists", isPresented: $showError) {
            Button("OK", role: .cancel) {
                isTextFieldFocused = true
            }
        } message: {
            Text("A configuration with the name '\(configName)' already exists. Please choose a different name.")
        }
    }
    
    private func saveIfValid() {
        guard !configName.isEmpty else { return }
        
        // Check if name already exists
        if configManager.hasConfigurationWithName(configName) {
            showError = true
            return
        }
        
        onSave(configName)
        dismiss()
    }
} 
