# UIHTML Console Error Rerouter

A robust solution for seamlessly integrating JavaScript console messages from MATLAB's `uihtml` components directly into the MATLAB Command Window. This tool centralizes your debugging efforts and gains immediate visibility into front-end issues without needing to inspect the browser's developer console separately.

---

## How It Works

1.  **MATLAB Class (`ConsoleErrorRerouter`)**: A simple class that wraps a `uihtml` component and listens for custom console events.
2.  **Inlined Shim Injection**: On construction, the class creates a temporary copy of your HTML file with an inlined JavaScript shim injected at the end of the `<body>`.
3.  **Setup Hook**: The shim automatically wraps your global `setup(htmlComponent)` function to capture the internal MATLAB component reference, allowing it to send messages back via `sendEventToMATLAB`.

---

## Getting Started

### 1. Requirements

For the rerouting to work, your HTML file **must** define a global `setup(htmlComponent)` function. This is the standard pattern for bidirectional communication in MATLAB `uihtml`.

```javascript
// index.html
function setup(htmlComponent) {
    // Your application logic here
    console.log("Application is ready!");
}
```

### 2. Basic Usage

Attach the rerouter to your `uihtml` component in MATLAB.

```matlab
fig = uifigure;
h = uihtml(fig);
h.HTMLSource = 'index.html';

% Create the rerouter
rerouter = ConsoleErrorRerouter(h);

% Optional: Configure which levels to intercept (default is just ["error"])
rerouter.ErrorLevels = ["error", "warn", "info", "log", "debug"];
```

---

## Features

*   **Configurable Error Levels**: Intercept `error`, `warn`, `info`, `log`, and `debug` messages.
*   **Custom Formatters**: Provide your own function handle to format the output.
*   **Non-Intrusive**: Uses `addlistener` to ensure it doesn't clobber any existing `HTMLEventReceivedFcn` or other event handlers you have registered.
*   **Clean Output**: Suppresses internal MATLAB backtraces for warnings to provide focused, relevant debugging information.
*   **Automatic Cleanup**: Destroys temporary files and restores the original `HTMLSource` when the object is deleted.

---

## Running Examples

Explore the `examples/` directory for ready-to-run scripts:

*   `basic_usage.m`: Simple demonstration of rerouting all console levels.
*   `custom_formatting.m`: Demonstrates how to use a custom function to format the rerouted messages.

---

## Testing

The project includes unit tests built with the `matlab.unittest` framework to verify the rerouter's behavior, including shim injection and message filtering.

To run the tests:
```matlab
results = runtests("tests/tConsoleErrorRerouter.m");
disp(results);
```
