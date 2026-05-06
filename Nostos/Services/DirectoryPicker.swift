import Foundation
import AppKit

protocol DirectoryPickerProtocol {
    func pickSourceDirectory() -> URL?
    func pickVaultDirectory() -> URL?
}

final class DefaultDirectoryPicker: DirectoryPickerProtocol {
    func pickSourceDirectory() -> URL? {
        if let uiTestingURL = ProcessInfo.processInfo.environment["UI_TESTING_SOURCE_DIRECTORY_TO_PICK"], !uiTestingURL.isEmpty {
            return URL(fileURLWithPath: uiTestingURL)
        }

        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.message = "Choose a folder to scan"
        panel.prompt = "Select"
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }

    func pickVaultDirectory() -> URL? {
        if let uiTestingURL = ProcessInfo.processInfo.environment["UI_TESTING_VAULT_DIRECTORY_TO_PICK"], !uiTestingURL.isEmpty {
            return URL(fileURLWithPath: uiTestingURL)
        }

        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.message = "Choose a vault folder"
        panel.prompt = "Select"
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }
}
