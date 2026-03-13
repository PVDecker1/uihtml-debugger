<script id="console-rerouter-shim">
(function() {
    var _userSetup = (typeof setup === 'function') ? setup : null;
    setup = function(htmlComponent) {
        var levels = ['error', 'warn', 'log', 'info', 'debug'];
        levels.forEach(function(level) {
            var _orig = console[level];
            console[level] = function() {
                var args = Array.prototype.slice.call(arguments);
                var message = args.map(function(a) {
                    if (a instanceof Error) return a.message;
                    if (typeof a === 'object') { try { return JSON.stringify(a); } catch(e) { return String(a); } }
                    return String(a);
                }).join(' ');
                var stack = (args[0] instanceof Error && args[0].stack) ? args[0].stack : '';
                htmlComponent.sendEventToMATLAB('ConsoleError', { level: level, message: message, stack: stack });
                if (typeof _orig === 'function') { _orig.apply(console, arguments); }
            };
        });
        if (_userSetup) { _userSetup(htmlComponent); }
    };
})();
</script>
