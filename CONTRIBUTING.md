# Contributing to Magic Switch

Thank you for your interest in contributing to Magic Switch! This guide will help you get started.

## How to Contribute

### Reporting Bugs

- Search [existing issues](https://github.com/byteflare-co/magic-switch/issues) to avoid duplicates
- Open a new issue with a clear title and description
- Include your macOS version, device model, and steps to reproduce

### Suggesting Features

- Open an issue with the **feature request** label
- Describe the use case and expected behavior

### Submitting Code

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Make your changes
4. Run tests (`make test`)
5. Commit your changes with a clear message
6. Push to your fork and open a Pull Request

## Development Setup

### Prerequisites

- macOS 13 (Ventura) or later
- Xcode 15+ or Swift 5.9+ toolchain
- Two Macs on the same network (for end-to-end testing)

### Getting Started

```bash
git clone https://github.com/byteflare-co/magic-switch.git
cd magic-switch
make build
make test
```

### Project Structure

```
Sources/
  MagicSwitch/       # App entry point, UI, menu bar
  MagicSwitchCore/   # Core logic: Bluetooth, networking, protocol
Tests/
  MagicSwitchTests/
  MagicSwitchCoreTests/
docs/                # Design documents and specifications
scripts/             # Build and release scripts
homebrew/            # Homebrew cask formula
```

## Code Style

- Follow standard Swift conventions and [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)
- Use meaningful variable and function names
- Keep functions focused and concise
- Add comments only where the intent is not obvious from the code

## Pull Request Process

1. Ensure your branch is up to date with `main`
2. Run `make test` and verify all tests pass
3. Update documentation if your change affects public behavior
4. Fill in the PR description with a summary of changes
5. Request a review from a maintainer

## License

By contributing, you agree that your contributions will be licensed under the [GPL-3.0 License](LICENSE).
