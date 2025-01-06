# BambuSwitcher

A macOS application that allows you to easily manage and switch between different Bambu Studio configurations.

## Features

- Create and save multiple Bambu Studio configurations
- Switch between configurations with a single click
- Automatic handling of all configuration files and settings
- Clean, modern macOS native interface
- Preserves all settings, including:
  - Printer configurations
  - User preferences
  - Network settings
  - Recent files
  - Cache and temporary data

## Installation

1. Download the latest release from the [Releases](https://github.com/jakergirard/BambuSwitcher/releases) page
2. Move BambuSwitcher.app to your Applications folder
3. Launch BambuSwitcher

## Usage

### Creating a New Configuration

1. Set up Bambu Studio exactly how you want it (login, preferences, etc.)
2. Close Bambu Studio
3. Open BambuSwitcher
4. Click "Save Current Config"
5. Enter a name for your configuration
6. Click Save

### Switching Configurations

1. Open BambuSwitcher with Bambu Studio closed
2. Select the configuration you want to use
3. Click "Launch Bambu Studio"
4. Bambu Studio will launch with the selected configuration

### Deleting Configurations

1. Select the configuration you want to remove
2. Click the "Delete" button
3. Confirm the deletion

## Requirements

- macOS 12.0 or later
- Bambu Studio installed in the Applications folder

## Building from Source

1. Clone the repository
2. Open the project in Xcode 14.0 or later
3. Build and run

## Technical Details

BambuSwitcher manages configurations by:
- Storing complete configuration snapshots in `~/Library/Application Support/BambuStudio_Configs`
- Handling all related configuration files (preferences, cache, etc.)
- Managing application state and user defaults

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details. 