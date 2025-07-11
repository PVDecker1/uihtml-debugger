UIHTML Console Error Rerouter
This project provides a robust solution for seamlessly integrating JavaScript console errors from MATLAB's uihtml components directly into the MATLAB command window. This allows developers to centralize their debugging efforts and gain immediate visibility into front-end issues without needing to inspect the browser's developer console separately.
Desired Behavior
The primary goal of this tool is to bridge the communication gap between the web content displayed in a uihtml component and the MATLAB environment. Specifically, when an error occurs within the JavaScript execution of a uihtml component, it should be:
 * Captured automatically: Errors that would normally appear in the browser's console should be intercepted.
  * Rerouted to the MATLAB Command Window: These captured errors should then be displayed prominently in the MATLAB command window, ideally in a format that distinguishes them from standard MATLAB output.
   * Non-intrusive: The rerouting mechanism should not interfere with other HTMLEventReceived events that the user might be handling for different purposes. Only console errors should trigger the rerouting behavior.
    * Easy to integrate: The solution should involve minimal setup, requiring a simple inclusion in the HTML file and an easy-to-use MATLAB class.
    Future Improvements
    This foundational setup offers several avenues for enhancement:
     * Configurable Error Levels: Allow users to specify which types of console messages (e.g., console.warn, console.info) should be rerouted.
      * Customizable Output Formatting: Provide options for users to define how error messages are displayed in the MATLAB command window.
       * Error Categorization: Implement more sophisticated parsing to categorize and filter errors based on their source or type.
        * Asynchronous Error Handling: Explore mechanisms for handling errors that occur asynchronously within the uihtml component.
         * Integration with Logging Frameworks: Enable the rerouter to hook into existing MATLAB logging frameworks for more comprehensive error management.
         Feel free to expand upon this foundation to meet more specific project requirements and enhance the debugging experience.
         