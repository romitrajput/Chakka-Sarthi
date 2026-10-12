# Contributing to Sanjay Roadlines Fleet Management App

Thank you for your interest in contributing! Please read this guide carefully before submitting any contributions.

## 📋 Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [How to Contribute](#how-to-contribute)
- [Pull Request Process](#pull-request-process)
- [Coding Standards](#coding-standards)
- [Commit Messages](#commit-messages)
- [Testing](#testing)
- [Documentation](#documentation)
- [Common Tasks](#common-tasks)

---

## Code of Conduct

- Be respectful and inclusive
- Focus on constructive feedback
- Help others learn and grow
- Keep discussions professional

---

## Getting Started

1. **Fork the repository** to your GitHub account
2. **Clone your fork** locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/fleet.git
   cd fleet
   ```
3. **Add the original repo as upstream**:
   ```bash
   git remote add upstream https://github.com/ORIGINAL_OWNER/fleet.git
   ```
4. **Create a feature branch**:
   ```bash
   git checkout -b feature/your-feature-name
   ```

---

## Development Setup

### Prerequisites

- Flutter SDK (^3.12.2)
- Dart (^3.12.2)
- Android Studio or VS Code with Flutter extension
- A Supabase account (free tier is fine)

### Setup Steps

```bash
# 1. Get dependencies
flutter pub get

# 2. Run code generation (if you modified providers)
flutter pub run build_runner build --delete-conflicting-outputs

# 3. Configure Supabase
# Copy lib/core/constants/supabase_constants.dart to a local override
# or set up your own Supabase project with the schema

# 4. Run the app
flutter run
```

### Recommended VS Code Extensions

- Dart (dart-code.dart-code)
- Flutter (dart-code.flutter)
- Error Lens (matangover.errorlens)

---

## How to Contribute

### Reporting Bugs

Before creating bug reports, please check the existing issues. When submitting a bug report:

1. Use the bug report template
2. Include steps to reproduce
3. Include expected vs actual behavior
4. Add screenshots/logs if applicable
5. Mention your Flutter/Dart version

### Suggesting Features

Feature requests are welcome! Please:

1. Check if the feature already exists or is being worked on
2. Explain why the feature would be useful
3. Provide use cases and examples

### Submitting Code

1. **Create an issue** first for significant changes (discuss the approach)
2. **Branch from main**: `git checkout -b feature/descriptive-name`
3. **Make your changes** following the coding standards
4. **Test your changes** thoroughly
5. **Update documentation** if needed
6. **Submit a Pull Request**

---

## Pull Request Process

### Before Submitting

- [ ] Code follows the project's coding style
- [ ] `flutter analyze` passes with no errors
- [ ] All existing tests pass (`flutter test`)
- [ ] New tests added for new functionality
- [ ] Documentation updated (README, comments, etc.)
- [ ] No sensitive data committed (API keys, credentials)

### PR Template

```markdown
## Description
<!-- Describe what this PR does -->

## Related Issue
<!-- Link to the issue this PR addresses -->

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update
- [ ] Refactoring

## Testing
<!-- Describe how you tested your changes -->

## Screenshots (if applicable)
<!-- Add screenshots here -->

## Checklist
- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] Tests added/updated
- [ ] Documentation updated
```

### Review Process

1. Maintainers will review your PR within 3-5 business days
2. Address any feedback or requested changes
3. Once approved, a maintainer will merge your PR

---

## Coding Standards

### Dart/Flutter Style

Follow the official [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style).

Key points:
- Use `flutter format` to format code
- Follow naming conventions:
  - `PascalCase` for classes, enums, typedefs
  - `camelCase` for variables, functions, parameters
  - `snake_case` for file names and directories
  - `_camelCase` for private members
- Keep functions small and focused
- Use meaningful variable names

### Project-Specific Conventions

#### File Structure
```
lib/
├── core/           # Shared utilities, constants, widgets
├── models/         # Data models
├── providers/      # Riverpod state management
├── repositories/   # Data access layer
└── screens/        # UI screens
```

#### Riverpod Providers
- Use `@riverpod` annotation for auto-generation
- Run `build_runner` after modifying providers
- Keep providers focused on single responsibilities

#### Widgets
- Extract reusable widgets into `core/widgets/`
- Use the existing color scheme (`AppColors`)
- Follow the existing component patterns

#### Supabase Queries
- All database queries go in `repositories/`
- Use the defined table names from `supabase_constants.dart`
- Handle errors appropriately

### Code Comments

- Add comments for complex logic
- Document public APIs
- Use clear, concise language
- Keep comments up to date

---

## Commit Messages

### Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation only
- `style`: Formatting, missing semicolons, etc. (no code change)
- `refactor`: Code change that neither fixes a bug nor adds a feature
- `test`: Adding or updating tests
- `chore`: Build process, dependencies, etc.

### Examples

```
feat(driver): add loading form validation

Added weight validation to prevent negative values.
Updated UI to show error messages clearly.

Closes #123
```

```
fix(auth): resolve MPIN login issue

Fixed the MPIN comparison logic that was case-sensitive.
```

---

## Testing

### Running Tests

```bash
# Run all tests
flutter test

# Run tests for a specific file
flutter test test/models/ticket_test.dart

# Run with coverage
flutter test --coverage
```

### Writing Tests

- Unit tests for models and utilities in `test/`
- Widget tests for UI components
- Integration tests for critical flows

---

## Documentation

### When to Update Documentation

- New features
- Changed APIs
- Updated dependencies
- New setup requirements
- Modified database schema

### What to Document

- Public APIs
- Complex algorithms
- Setup/configuration steps
- Known limitations
- Usage examples

---

## Common Tasks

### Adding a New Screen

1. Create the screen in the appropriate folder (`screens/admin/` or `screens/driver/`)
2. Add the route in `lib/app.dart`
3. Follow existing screen patterns

### Adding a New Model

1. Create the model in `lib/models/`
2. Include `fromJson` and `toJson` methods
3. Add any necessary utility methods

### Adding a New Provider

1. Create the provider in `lib/providers/`
2. Use `@riverpod` annotation
3. Run `build_runner` to generate code

### Adding a New Repository Method

1. Add the method to the appropriate repository in `lib/repositories/`
2. Use Supabase client for database operations
3. Handle errors appropriately

### Adding Translations

1. Add translations to `lib/core/constants/app_translations.dart`
2. Use the `tr()` extension or `AppTranslations.translate()` method
3. Test in all supported languages

---

## Getting Help

- Check existing issues and PRs
- Read the codebase comments
- Ask in the project discussions
- Be specific when asking for help

---

## Recognition

Contributors will be recognized in the project. Significant contributions may be highlighted in the README.

Thank you for contributing to the project! 🎉
