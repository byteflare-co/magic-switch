# Magic Switch

> Switch your Magic Keyboard and Magic Trackpad between Macs with one click.

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue)
![Swift 5.9+](https://img.shields.io/badge/Swift-5.9%2B-orange)
![License: GPL-3.0](https://img.shields.io/badge/License-GPL--3.0-green)

Magic Switch is a lightweight macOS menu bar app that lets you seamlessly switch your Bluetooth Magic Keyboard and Magic Trackpad between two Macs — no re-pairing, no cables, just one click.

## Features

- **One-click switching** — Switch Magic Keyboard/Trackpad between Macs instantly from the menu bar
- **Rich popover UI** — Menu bar app with an intuitive popover interface
- **Auto-discovery** — Automatically discovers other Macs on your network via Bonjour
- **Blue Switch compatible** — Implements a protocol compatible with [Blue Switch](https://github.com/nicola02nb/Blue-Switch)
- **Battery monitoring** — Keep track of your devices' battery levels
- **Keyboard shortcuts** — Customizable global keyboard shortcuts for quick switching
- **Setup wizard** — Guided first-run setup to get you started quickly

## Screenshots

<!-- TODO: Add screenshots -->

## Requirements

- macOS 13 (Ventura) or later
- Swift 5.9+
- Two Macs on the same local network

## Installation

### Homebrew

```bash
brew tap byteflare-co/tap
brew install --cask magic-switch
```

### Manual

Download the latest release from [GitHub Releases](https://github.com/byteflare-co/magic-switch/releases).

### Build from Source

```bash
git clone https://github.com/byteflare-co/magic-switch.git
cd magic-switch
make run
```

## How It Works

1. Install Magic Switch on both of your Macs
2. Connect both Macs to the same local network
3. Magic Switch automatically discovers the other Mac via Bonjour
4. Click the menu bar icon and select **Switch** — your Magic Keyboard and Trackpad disconnect from the current Mac and connect to the other one

Under the hood, Magic Switch uses Bluetooth HID commands to manage device connections and a lightweight network protocol to coordinate between Macs.

## Usage

Once launched, Magic Switch lives in your menu bar. Click the icon to open the popover:

- **Switch** — Transfer your devices to the other Mac
- **Devices** — View connected Magic Keyboard and Trackpad with battery levels
- **Peer** — See the discovered peer Mac and its connection status
- **Settings** — Configure keyboard shortcuts, launch at login, and more

## Building

```bash
# Debug build
make build

# Release build
make release

# Run (debug)
make run

# Run tests
make test

# Create .app bundle
make bundle

# Create .app bundle and open
make bundle-run

# Clean
make clean
```

## Configuration

Magic Switch stores its configuration at:

```
~/Library/Application Support/MagicSwitch/
```

Logs are written to:

```
~/Library/Logs/MagicSwitch/
```

## Blue Switch Compatibility

Magic Switch implements a protocol compatible with [Blue Switch](https://github.com/nicola02nb/Blue-Switch), allowing interoperability between the two applications. See [docs/blue-switch-spec.md](docs/blue-switch-spec.md) and [docs/spec-diff.md](docs/spec-diff.md) for protocol details.

## Documentation

Design documents and specifications are available in the [docs/](docs/) directory:

- [Architecture](docs/architecture.md)
- [Requirements](docs/requirements.md)
- [Blue Switch Protocol Spec](docs/blue-switch-spec.md)
- [Spec Differences](docs/spec-diff.md)
- [UI Requirements](docs/ui-requirements.md)
- [Test Scenarios](docs/test-scenarios.md)

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

This project is licensed under the GNU General Public License v3.0 — see the [LICENSE](LICENSE) file for details.

Magic Switch uses the GPL-3.0 license to maintain compatibility with [Blue Switch](https://github.com/nicola02nb/Blue-Switch).
