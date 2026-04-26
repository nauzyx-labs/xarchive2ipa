# xarchive2ipa

A premium, native macOS CLI tool to convert Xcode `.xcarchive` bundles into ready-to-install `.ipa` files.

## Features
- **Native Performance**: Written in Swift for high speed and reliability.
- **Interactive Selection**: Supports `fzf` for a premium search experience, with a clean fallback selector.
- **Automatic Discovery**: Finds your Xcode archives automatically in `~/Library/Developer/Xcode/Archives`.
- **Proper Packaging**: Ensures correct `Payload` structure and preserves symlinks/permissions.

## Installation

### Easy Install (Local)
If you have the source code, simply run:
```bash
chmod +x install.sh
./install.sh
```

### Manual Build
```bash
make
sudo mv xarchive2ipa /usr/local/bin/
```

## Usage
Just run `xarchive2ipa` in your terminal:
```bash
xarchive2ipa
```

## Requirements
- macOS
- Xcode Command Line Tools (`swiftc`)
- `fzf` (Optional, for premium experience)

---
Created by [github.com/xyzuan](https://github.com/xyzuan)
