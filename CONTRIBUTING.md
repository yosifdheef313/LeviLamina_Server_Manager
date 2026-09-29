# Contributing to LeviLamina Server Manager

Thank you for your interest in contributing to **LeviLamina Server Manager**! This document provides guidelines for code standards, development workflows, and submitting pull requests.

---

## Code of Conduct

We are committed to providing a welcoming, inclusive, and harassment-free environment for all contributors. Please be respectful and collaborative in all discussions and code reviews.

---

## Development Setup

1. **Clone the repository**:
   ```bash
   git clone https://github.com/yosifdheef313/LeviLaminaServerManager.git
   cd LeviLaminaServerManager
   ```

2. **Install frontend dependencies**:
   ```bash
   cd frontend
   npm install
   cd ..
   ```

3. **Verify Go dependencies**:
   ```bash
   go mod tidy
   ```

4. **Launch development environment**:
   ```bash
   wails dev
   # Or using the build script:
   build.bat dev
   ```

---

## Code Style & Standards

### Go (Backend)
- All Go code must be formatted using the standard toolchain:
  ```bash
  gofmt -s -w backend/
  ```
- All exported functions, structs, interfaces, and packages must include clear Go Doc comments.
- Keep functions focused and maintain clear package boundaries. Backend modules (`process`, `addons`, `backups`) must not import `github.com/wailsapp/wails/v2/pkg/runtime` directly; all Wails interactions should remain in `backend/app.go`.
- Run all unit tests before submitting:
  ```bash
  go test -v ./backend/...
  ```

### TypeScript / React (Frontend)
- Use standard TypeScript interfaces and types. Avoid `any` whenever possible.
- Format frontend files using Prettier and verify linting:
  ```bash
  cd frontend
  npm run build
  ```
- Keep UI text out of components; use `t('key', 'Default English Text')` to support multilingual translations (`frontend/src/i18n/locales/`).

---

## Commit Message Guidelines

We follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <short description>

[optional body]
```

### Types:
- `feat`: A new user-facing feature or enhancement.
- `fix`: A bug fix.
- `docs`: Documentation updates (README, ARCHITECTURE, comments).
- `style`: Formatting, missing semicolons, no code changes.
- `refactor`: Code restructuring without behavior changes.
- `test`: Adding or updating test cases.
- `chore`: Build scripts, dependencies, or toolchain adjustments.

### Examples:
- `feat(process): add real-time RakNet UDP tick rate calculation`
- `fix(addons): correctly parse multi-module pack manifests`
- `docs: update ARCHITECTURE.md with job object explanation`

---

## Pull Request Process

1. Fork the repository and create your branch from `main`:
   ```bash
   git checkout -b feat/my-new-feature
   ```
2. Commit your changes following the commit message guidelines.
3. Verify that all tests pass:
   ```bash
   go test ./backend/...
   cd frontend && npm run build && cd ..
   ```
4. Push your branch to your fork and open a Pull Request against `main`.
5. Clearly describe the problem your PR solves and attach screenshots if your changes affect the UI.
