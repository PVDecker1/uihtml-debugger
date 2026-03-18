# AGENTS.md — UIHTML Debugger Toolkit

This file instructs AI agents on how to understand, navigate, and contribute to this project correctly.

---

## Project Overview

**UIHTML Debugger Toolkit** is an open-source MATLAB project containing two primary tools for `uihtml` development:
1. **Console Error Rerouter** — Intercepts JavaScript `console` calls and forwards them to the MATLAB Command Window.
2. **UIHTML DevTools** — Injects the [Eruda](https://github.com/liriliri/eruda) dev tools into a `uihtml` component for on-page inspection.

---

## Repository Layout

```
uihtml-debugger/
├── AGENTS.md                   ← you are here
├── README.md
├── LICENSE
├── uihtml-debugger.prj         ← MATLAB Toolbox Project file
│
├── toolbox/                    ← packageable toolbox content
│   ├── ConsoleErrorRerouter.m  ← Rerouter class
│   ├── UIHTMLDevTools.m        ← DevTools injector class
│   ├── Support/                ← Internal shims (e.g., shim_lines.js)
│   ├── vendor/                 ← Third-party libraries (e.g., eruda.js)
│   └── examples/
│       ├── basic_usage.m
│       ├── custom_formatting.m
│       ├── devtools_usage.m    ← Full toolkit demonstration
│       └── html/
│
└── tests/                      ← unit tests
    ├── tConsoleErrorRerouter.m
    ├── tUIHTMLDevTools.m       ← Combined DevTools tests
    ├── MockComponent.m         ← Testing utility for handle mocks
    └── html/
```

---

## Coding Conventions

### MATLAB
- **Style**: Follow MathWorks MATLAB style guidelines.
  - `lowerCamelCase` for variables and function names.
  - `UpperCamelCase` for class names and properties.
  - Lines must not exceed **100 characters**.
- **Classes**: Use `classdef` with `properties` blocks. Document every public property and method.
- **Error IDs**: Use namespaced error IDs in all `error()` calls: `error('uihtmlDebugger:badArgument', '...')`.
- **Backward compatibility**: Target MATLAB R2023a and later.

### JavaScript (Inlined Shims & Vendor)
- **ES5 compatible** for shims to ensure maximum browser compatibility.
- Vendor libraries (like Eruda) are managed in `toolbox/vendor/`.

---

## Key Interfaces

### `ConsoleErrorRerouter`
| Member | Type | Description |
|---|---|---|
| `Enabled` | Property (`logical`) | Toggles rerouting. |
| `ErrorLevels` | Property (`string` array) | Levels to intercept (`"error"`, `"warn"`, etc.). |
| `FormatFcn` | Property (`function_handle`) | Custom output formatter. |

### `UIHTMLDevTools`
| Member | Type | Description |
|---|---|---|
| `Enabled` | Property (`logical`) | Toggles Eruda injection. |

---

## What Agents Should and Should Not Do

### ✅ Agents MAY
- Add new methods or properties that are additive and backward-compatible.
- Add new tests to `tests/`.
- Add new example scripts under `examples/`.
- Improve inline documentation.

### ❌ Agents MUST NOT
- Remove or rename public properties/methods listed above.
- Introduce new toolbox dependencies.
- Use `eval` in MATLAB code.

---

## Testing

Tests use the `matlab.unittest` framework.

**Run all tests:**
```matlab
results = runtests('tests/');
disp(results);
```

**Coverage Target**: Maintain at least **85%** code coverage for classes in `toolbox/`.

---

## CI/CD

The project uses GitHub Actions (`.github/workflows/matlab-tests.yml`) to:
1. Run tests on every PR and push to `main`.
2. Package the toolbox (`.mltbx`) on every push to `main`.
3. Create a GitHub Release when a version tag (e.g., `v1.2.3`) is pushed.
