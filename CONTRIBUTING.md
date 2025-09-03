# Contributing to OpenIAP

Thank you for your interest in contributing! We love your input and appreciate your efforts to make OpenIAP better.

## Quick Start

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Run tests (`swift test`)
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to your branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

## Development Setup

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/openiap-ios.git
cd openiap-ios

# Open in Xcode
open Package.swift

# Run tests
swift test
```

## Code Style

- Follow Swift API Design Guidelines
- Use meaningful variable and function names
- Keep functions small and focused
- Add comments only when necessary

### Naming Conventions

- **Acronyms**: Use Pascal case when at beginning/middle (`IapModule`, `IosIapTests`)
- **Acronyms as suffix**: Use all caps (`ProductIAP`, `ManagerIOS`)
- See [CLAUDE.md](CLAUDE.md) for detailed naming rules

## Testing

All new features must include tests:

```swift
func testYourFeature() async throws {
    // Arrange
    let module = IapModule.shared
    
    // Act
    let result = try await module.yourMethod()
    
    // Assert
    XCTAssertEqual(result, expectedValue)
}
```

## Pull Request Guidelines

### ✅ Do

- Write clear PR titles and descriptions
- Include tests for new features
- Update documentation if needed
- Keep changes focused and small

### ❌ Don't

- Mix unrelated changes in one PR
- Break existing tests
- Change code style without discussion
- Include commented-out code

## Commit Messages

Keep them clear and concise:

- `Add purchase error recovery`
- `Fix subscription status check`
- `Update StoreKit 2 integration`
- `Refactor transaction handling`

## Release Process (Maintainers Only)

When your PR is merged, maintainers will handle the release:

1. **Version Update**: We use semantic versioning (major.minor.patch)
   ```bash
   ./scripts/bump-version.sh patch  # for bug fixes
   ./scripts/bump-version.sh minor  # for new features
   ./scripts/bump-version.sh major  # for breaking changes
   ```

2. **Automatic Deployment**: Creating a GitHub release triggers:
   - Swift Package Manager update (immediate)
   - CocoaPods deployment (via `pod trunk push`)

3. **Availability**: 
   - Swift Package: Available immediately after release
   - CocoaPods: Available within ~10 minutes via `pod update`

Contributors don't need to worry about deployment - just focus on making great contributions!

## Questions?

Feel free to:
- Open an issue for bugs or features
- Start a discussion for questions
- Tag @hyodotdev for urgent matters

## License

By contributing, you agree that your contributions will be licensed under the MIT License.