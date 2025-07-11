/**
 * UIHtml Error Rerouter Script
 * 
 * This script overrides the console.error function to reroute JavaScript
 * console errors from uihtml components to the MATLAB command window.
 * 
 * Usage: Include this script in your HTML file:
 * <script src="path/to/uihtml-error-rerouter.js"></script>
 * 
 * The script will automatically capture console.error() calls and send
 * them to MATLAB via the uihtml messaging mechanism.
 */

(function() {
    'use strict';
    
    // Save reference to original console.error function
    var originalConsoleError = console.error;
    
    // Override console.error to capture and reroute errors
    console.error = function() {
        // Convert arguments to array for easy manipulation
        var args = Array.prototype.slice.call(arguments);
        
        // Format error message for MATLAB
        var errorMessage = "UIHTML Console Error: " + args.join(' ');
        
        // Send error to MATLAB if uihtml messaging is available
        if (typeof matlab !== 'undefined' && matlab.postMessage) {
            try {
                matlab.postMessage(JSON.stringify({
                    type: 'consoleError',
                    message: errorMessage,
                    timestamp: new Date().toISOString(),
                    args: args
                }));
            } catch (e) {
                // Fallback if postMessage fails
                originalConsoleError.call(console, 'UIHtml Error Rerouter: Failed to send error to MATLAB:', e);
            }
        }
        
        // Also call original console.error to maintain browser console output
        originalConsoleError.apply(console, args);
    };
    
    // Optional: Also capture unhandled JavaScript errors
    window.addEventListener('error', function(event) {
        var errorMessage = 'Unhandled JavaScript Error: ' + event.message + 
                          ' at ' + event.filename + ':' + event.lineno + ':' + event.colno;
        
        if (typeof matlab !== 'undefined' && matlab.postMessage) {
            try {
                matlab.postMessage(JSON.stringify({
                    type: 'consoleError',
                    message: errorMessage,
                    timestamp: new Date().toISOString(),
                    error: {
                        message: event.message,
                        filename: event.filename,
                        lineno: event.lineno,
                        colno: event.colno
                    }
                }));
            } catch (e) {
                originalConsoleError.call(console, 'UIHtml Error Rerouter: Failed to send unhandled error to MATLAB:', e);
            }
        }
    });
    
    // Initialize message to confirm script is loaded
    if (typeof matlab !== 'undefined' && matlab.postMessage) {
        try {
            matlab.postMessage(JSON.stringify({
                type: 'consoleError',
                message: 'UIHtml Error Rerouter: Successfully initialized',
                timestamp: new Date().toISOString()
            }));
        } catch (e) {
            // Silent fail for initialization message
        }
    }
    
})();