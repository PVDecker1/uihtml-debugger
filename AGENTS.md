# AGENTS.md — UIHTML Console Error Rerouter

This file instructs AI agents (e.g., Google Gemini Jules) on how to understand,
navigate, and contribute to this project correctly.

---

## Project Overview

**UIHTML Console Error Rerouter** is an open-source MATLAB tool that intercepts
JavaScript `console.error` calls inside MATLAB `uihtml` components and forwards
them to the MATLAB Command Window. This bridges the gap between front-end
JavaScript debugging and MATLAB's native output, eliminating the need to open a
browser developer console during development.

The tool has two integrated parts:
1. **JavaScript shim** — injected into the HTML file loaded by `uihtml`; intercepts
   `console.error` (and optionally `console.warn`, `console.info`) and sends the
   message back to MATLAB via `sendEventToMATLAB`.
2. **MATLAB class (`ConsoleErrorRerouter`)** — wraps a `uihtml` component, listens
   for `HTMLEventReceived` events tagged as console errors, and prints them to the
   Command Window without interfering with other event handlers the user may have
   registered.

---

## Repository Layout

```
uihtml-console-rerouter/
├── AGENTS.md                   ← you are here
├── README.md
├── LICENSE
│
├── toolbox/                    ← packageable toolbox content
│   ├── ConsoleErrorRerouter.m  ← main MATLAB class (includes inlined shim)
│   ├── Contents.m              ← toolbox summary for 'help'
│   └── examples/
│       ├── basic_usage.m       ← minimal working example
│       ├── custom_formatting.m ← example using formatting options
│       └── html/
│           └── example_page.html
│
└── tests/                      ← unit tests (infrastructure)
    ├── tConsoleErrorRerouter.m
    └── html/
        └── test_page.html
```

---

## Coding Conventions

### MATLAB
- **Style**: Follow MathWorks MATLAB style guidelines.
  - `lowerCamelCase` for variables and function names.
  - `UpperCamelCase` for class names and properties.
  - Lines must not exceed **100 characters**.
- **Classes**: Use `classdef` with `properties` blocks. Separate dependent
  properties into their own `properties (Dependent)` block. Document every public
  property and method with a one-line comment above the declaration.
- **Error IDs**: Use namespaced error IDs in all `error()` calls:
  `error('uihtmlRerouter:badArgument', 'Message here.')`.
- **No global state**: Do not use `global` or `persistent` variables in the main
  class. Encapsulate all state as object properties.
- **Backward compatibility**: Target MATLAB R2023a and later. While `uihtml` itself
  was introduced in R2019b, the bidirectional event API this tool depends on —
  specifically `sendEventToMATLAB` (JavaScript) and `HTMLEventReceivedFcn` (MATLAB)
  — was not introduced until R2023a (see Version History on the
  [uihtml docs page](https://www.mathworks.com/help/matlab/ref/uihtml.html)).
  Do not use language features introduced after R2023a without a version guard.

### JavaScript (Inlined Shim)
- **ES5 compatible** — the embedded browser in older MATLAB releases may not
  support ES6+ syntax. Use `var`, not `let`/`const`. Use function declarations,
  not arrow functions.
- The shim must be self-contained and is injected into the HTML as a `<script>`
  block during construction of `ConsoleErrorRerouter`.
- The shim must call `htmlComponent.sendEventToMATLAB` using the reserved event
  name `"ConsoleError"` and pass a plain object `{ level, message, stack }`.
- Do not rename or repurpose the `"ConsoleError"` event name — the MATLAB class
  filters on this string.

### HTML examples / fixtures
- Keep example HTML files minimal — their purpose is to demonstrate the shim, not
  showcase web design.
- **Requirement**: Every HTML file must define a global `setup(htmlComponent)`
  function for the shim to correctly hook into the bidirectional communication bridge.

---

## Key Interfaces (do not change without updating tests)

### `ConsoleErrorRerouter` MATLAB class

| Member | Type | Description |
|---|---|---|
| `ConsoleErrorRerouter(uihtmlComp)` | Constructor | Accepts a `matlab.ui.control.HTML` object. Registers the internal `HTMLEventReceived` callback. |
| `Enabled` | Property (`logical`) | Toggles rerouting on/off without destroying the object. Default: `true`. |
| `ErrorLevels` | Property (`string` array) | Console levels to intercept. Default: `["error"]`. Allowed: `"error"`, `"warn"`, `"info"`, `"log"`, `"debug"`. |
| `FormatFcn` | Property (`function_handle`) | Custom formatter `f(level, message, stack) → char`. Default: built-in red-text formatter using `fprintf`. |
| `delete()` | Destructor | Unregisters only the rerouter's listener; preserves any other `HTMLEventReceived` listeners on the component. |

### JavaScript shim event payload

```json
{
  "level":   "error",
  "message": "Uncaught TypeError: cannot read property...",
  "stack":   "TypeError: ...\n    at foo (example.html:42)"
}
```

---

## What Agents Should and Should Not Do

### ✅ Agents MAY
- Add new methods or properties to `ConsoleErrorRerouter` that are additive and
  backward-compatible.
- Extend `ErrorLevels` support in both the JS shim and the MATLAB class.
- Add new tests to `tests/tConsoleErrorRerouter.m`.
- Add new example scripts under `examples/`.
- Improve inline documentation (comments, help text).
- Refactor internals for clarity, as long as all public interfaces remain unchanged.
- Fix bugs, provided the fix is covered by a new or updated test.

### ❌ Agents MUST NOT
- Change the `"ConsoleError"` event name string in either the JS or MATLAB code
  without a coordinated update to both sides and all tests.
- Introduce any new MATLAB toolbox dependency (the tool must run on MATLAB base
  with no additional toolboxes).
- Use `evalin`, `evalc`, or `eval` anywhere in MATLAB code.
- Modify the inlined shim logic in `ConsoleErrorRerouter.m` to use ES6+ syntax
  without a compatibility gate.
- Remove or rename any public property or method listed in the Key Interfaces table.
- Add files outside the directory structure defined above without updating this
  AGENTS.md and the README.

---

## Testing

All tests live in `tests/tConsoleErrorRerouter.m` and use the `matlab.unittest`
framework.

**Run tests:**
```matlab
results = runtests('tests/tConsoleErrorRerouter.m');
disp(results)
```

**Every pull request must:**
1. Pass all existing tests with zero failures and zero errors.
2. Include new tests for any new behavior introduced.
3. Not decrease code coverage on the `ConsoleErrorRerouter` class.

When adding tests, follow this pattern:

```matlab
methods (Test)
    function myNewTest(testCase)
        % Arrange
        comp = createMockUihtmlComponent();
        rerouter = ConsoleErrorRerouter(comp);

        % Act
        fireConsoleErrorEvent(comp, 'error', 'Test message');

        % Assert
        testCase.verifyEqual(rerouter.LastMessage, 'Test message');
    end
end
```

---

## Pull Request Checklist

Before opening a PR, verify:

- [ ] `runtests('tests/')` passes with zero failures
- [ ] New public API changes are reflected in this AGENTS.md and in README.md
- [ ] No new toolbox dependencies introduced
- [ ] JavaScript shim remains ES5 compatible
- [ ] `consoleShim.js` and `ConsoleErrorRerouter.m` use the same event name string

---

## Out of Scope for This Repository

- General-purpose MATLAB logging frameworks (the tool is intentionally narrow)
- Support for MATLAB versions prior to R2023a
- Integration with MATLAB Online's browser environment (behavior there is
  unverified and untested)
- Any UI beyond what `uihtml` provides natively

---

## Questions / Contact

Open a GitHub issue with the label `question` for design discussions, or `bug` for
defects. Feature requests should use the `enhancement` label and briefly describe
the use case before proposing an implementation.
