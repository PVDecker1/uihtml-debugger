# Testing ConsoleErrorRerouter

Testing `ConsoleErrorRerouter` is uniquely challenging because it interacts with the internal state of the `matlab.ui.control.HTML` component, which is a **Sealed** class in MATLAB. This means it cannot be subclassed or mocked using the standard `createMock` method from `matlab.mock.TestCase`.

## Testing Strategy

To overcome the sealed class limitation, we use a **Functional Testing** approach with a real `uihtml` component inside a hidden `uifigure`.

### 1. The "Sealed Class" Workaround
Instead of mocking the `uihtml` component, we instantiate a real one during `TestMethodSetup`. This ensures that `ConsoleErrorRerouter`'s strict type validation (`arguments` block) passes and that the real event-handling logic is exercised.

### 2. Synchronization (The "Ready" Handshake)
Web components in MATLAB load asynchronously. To prevent tests from firing events before the page is ready, we implemented a "Ready" event handshake:
- **HTML Side**: `tests/html/test_page.html` sends a `Ready` event to MATLAB once the `setup` function completes.
- **MATLAB Side**: `tConsoleErrorRerouter` tracks these events using a `ReadyFired` counter property.

**Crucial Note**: Instantiating `ConsoleErrorRerouter` causes the `HTMLSource` to change (to inject the shim), which triggers a **reload** of the page. Tests must wait for this second "Ready" event before proceeding to trigger console messages.

### 3. Triggering Console Messages
Since we cannot manually notify the `HTMLEventReceived` event on a real `uihtml` component (it has restricted `NotifyAccess`), we trigger actual JavaScript console calls from MATLAB:
- We use `sendEventToHTMLSource(component, 'triggerTest', struct('level', level, 'msg', message))` to send a command to the page.
- The page's JavaScript listens for this event and calls `console[level](message)`.
- The `ConsoleErrorRerouter` shim intercepts this call and routes it back to MATLAB, updating the `LastMessage` property.

### 4. Verification
- **LastMessage**: Verified for all levels (`error`, `warn`, `info`, `log`, `debug`).
- **Warnings**: Verified using `testCase.verifyWarning` for the `warn` level.
- **Shim Injection**: Verified by checking for the existence of the temporary `_rerouter_` HTML file and ensuring it is cleaned up on destruction.

## Files Involved
- `toolbox/ConsoleErrorRerouter.m`: The primary class under test.
- `tests/tConsoleErrorRerouter.m`: The main test suite.
- `tests/html/test_page.html`: The test page with event listeners for triggering console messages.
- `toolbox/Support/shim_lines.js`: The JavaScript shim injected and monitored by the Rerouter.
