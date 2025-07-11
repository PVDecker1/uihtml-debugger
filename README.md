# UIHTML Console Error Rerouter

This project provides a robust solution for seamlessly integrating JavaScript console errors from MATLAB's uihtml components directly into the MATLAB command window. This allows developers to centralize their debugging efforts and gain immediate visibility into front-end issues without needing to inspect the browser's developer console separately.

## Quick Start

Using this debugger requires only **two simple steps**:

### Step 1: Include the Error Rerouting Script
Add this script tag to your HTML file:
```html
<script src="path/to/uihtml-error-rerouter.js"></script>
```

### Step 2: Attach the Debugger Class
In your MATLAB code:
```matlab
% Create your uihtml component
h = uihtml(parent);
h.HTMLSource = 'your-file.html';

% Add the debugger class to your path
addpath('path/to/src');

% Attach the error logger
errorLogger = UIHtmlErrorLogger(h);
```

That's it! Console errors from your HTML will now appear in the MATLAB command window.

## Installation

1. Download or clone this repository
2. Copy the files to your project:
   - `js/uihtml-error-rerouter.js` - Include this in your HTML files
   - `src/UIHtmlErrorLogger.m` - Add this MATLAB class to your path

## File Structure

```
uihtml-debugger/
├── js/
│   └── uihtml-error-rerouter.js    # JavaScript error rerouting script
├── src/
│   └── UIHtmlErrorLogger.m         # MATLAB error logger class
├── examples/
│   ├── minimal_example.html        # Minimal usage example (HTML)
│   ├── minimal_example.m           # Minimal usage example (MATLAB)
│   ├── demo.html                   # Full featured demo (HTML)
│   └── demo_matlab.m               # Full featured demo (MATLAB)
└── README.md
```

## Examples

### Minimal Example
See `examples/minimal_example.html` and `examples/minimal_example.m` for the simplest possible usage.

### Full Demo
Run `examples/demo_matlab.m` for a comprehensive demonstration with multiple error types and interactive testing.

## Features

- **Automatic Error Capture**: Intercepts `console.error()` calls and unhandled JavaScript errors
- **MATLAB Integration**: Displays errors directly in the MATLAB command window with timestamps
- **Non-intrusive**: Doesn't interfere with existing HTMLEventReceived event handling
- **Browser Console Preserved**: Errors still appear in browser developer console for debugging
- **Easy Integration**: Minimal setup with just two steps
- **Robust Error Handling**: Gracefully handles JSON parsing errors and communication failures

## How It Works

1. **JavaScript Side**: The `uihtml-error-rerouter.js` script overrides `console.error()` and captures unhandled errors, then sends them to MATLAB via the uihtml messaging system.

2. **MATLAB Side**: The `UIHtmlErrorLogger` class listens for `HTMLEventReceived` events, filters for console error messages, and displays them in the command window.

## Error Message Format

Errors appear in the MATLAB command window like this:
```
[14:23:45] UIHTML Console Error: Uncaught ReferenceError: undefinedVariable is not defined
  Source: demo.html (line 42)
```

## API Reference

### UIHtmlErrorLogger Class

#### Constructor
```matlab
errorLogger = UIHtmlErrorLogger(htmlComponent)
```
- `htmlComponent`: A `matlab.ui.control.HTML` object

#### Methods
- `getStatus()`: Returns current status of the error logger
- `delete()`: Manually stop listening (called automatically when object is cleared)

## Future Improvements

This foundational setup offers several avenues for enhancement:
- **Configurable Error Levels**: Allow users to specify which types of console messages (e.g., console.warn, console.info) should be rerouted
- **Customizable Output Formatting**: Provide options for users to define how error messages are displayed in the MATLAB command window
- **Error Categorization**: Implement more sophisticated parsing to categorize and filter errors based on their source or type
- **Asynchronous Error Handling**: Explore mechanisms for handling errors that occur asynchronously within the uihtml component
- **Integration with Logging Frameworks**: Enable the rerouter to hook into existing MATLAB logging frameworks for more comprehensive error management

## License

Feel free to expand upon this foundation to meet more specific project requirements and enhance the debugging experience.
         