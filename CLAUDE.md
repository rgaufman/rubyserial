# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Architecture Overview

RubySerial is a cross-platform Ruby gem for serial port communication using FFI (Foreign Function Interface). The architecture is platform-specific:

### Platform Detection and Loading
- `lib/rubyserial.rb` handles platform detection and loads appropriate modules
- Windows: loads `windows_constants.rb` and `windows.rb`
- Linux: loads `linux_constants.rb` and `posix.rb`
- macOS: loads `osx_constants.rb` and `posix.rb`

### Core Implementation
- `lib/rubyserial/posix.rb` contains the main `Serial` class for POSIX systems (Linux/macOS)
- `lib/rubyserial/windows.rb` contains Windows-specific implementation
- Platform-specific constants files define baud rates, data bits, parity, and system calls

### Key Features
- Cross-platform serial communication (Windows, Linux, macOS)
- Uses FFI for native system calls without requiring compilation
- Supports standard serial parameters: baud rate, data bits, parity, stop bits
- Provides both synchronous and asynchronous reading methods
- New `gets` method with customizable separator and limit parameters
- New `readline` method with timeout support

## Common Development Commands

### Setup
```bash
bundle install
```

### Running Tests
```bash
bundle exec rspec
```

Run specific test file:
```bash
bundle exec rspec spec/rubyserial_spec.rb
```

### Code Quality
```bash
bundle exec rubocop
```

Auto-fix style issues:
```bash
bundle exec rubocop -a
```

### Test Dependencies
Tests require `socat` on Unix systems or `com0com` on Windows for creating virtual serial port pairs.

Install socat on macOS:
```bash
brew install socat
```

Install socat on Linux:
```bash
sudo apt-get install socat
```

### Building and Releasing
The gem uses standard Bundler tasks defined in `Rakefile`:
```bash
bundle exec rake build
bundle exec rake release
```

## Key Implementation Details

### Serial Port Configuration
- Baud rates, data bits, parity, and stop bits are configured via platform-specific constants
- POSIX implementation uses termios structures for port configuration
- Configuration differences between Linux and macOS are handled in `build_config` method

### Error Handling
- All platform-specific errors are wrapped in `RubySerial::Error` which inherits from `IOError`
- Error codes are mapped from system errno values to descriptive messages

### Recent Enhancements
- `gets` method supports named parameters for separator and limit
- `readline` method provides timeout functionality
- Code has been modernized with Ruby 3.4+ requirements