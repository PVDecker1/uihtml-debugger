import matlab.unittest.TestRunner;
import matlab.unittest.TestSuite;
import matlab.unittest.plugins.CodeCoveragePlugin;
import matlab.unittest.plugins.codecoverage.CoberturaFormat;

% Create suite
suite = TestSuite.fromFolder('tests', 'IncludingSubfolders', true);

% Create runner
runner = TestRunner.withTextOutput;

% Configure coverage
sourceFiles = { ...
    fullfile(pwd, 'toolbox', 'ConsoleErrorRerouter.m'), ...
    fullfile(pwd, 'toolbox', 'UIHTMLDevTools.m') ...
};

mkdir('code-coverage');
coverageFile = fullfile(pwd, 'code-coverage', 'coverage.xml');
plugin = CodeCoveragePlugin.forFile(sourceFiles, ...
    'Producing', CoberturaFormat(coverageFile));
runner.addPlugin(plugin);

% Run tests
results = runner.run(suite);

% Output results for CI
display(results);
assertSuccess(results);
