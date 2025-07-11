%% Test UIHtmlErrorLogger Class Syntax
% This script tests that the UIHtmlErrorLogger class can be loaded
% and its basic methods work without requiring an actual uihtml component

fprintf('Testing UIHtmlErrorLogger class syntax and basic functionality...\n\n');

try
    % Add source directory to path
    addpath(fullfile(pwd, 'src'));
    
    % Test 1: Check if class can be loaded
    fprintf('Test 1: Loading UIHtmlErrorLogger class...\n');
    metadata = ?UIHtmlErrorLogger;
    fprintf('✓ Class loaded successfully\n');
    fprintf('  Class name: %s\n', metadata.Name);
    fprintf('  Superclasses: %s\n', strjoin({metadata.SuperclassList.Name}, ', '));
    
    % Test 2: Check class methods
    fprintf('\nTest 2: Checking class methods...\n');
    methods_list = {metadata.MethodList.Name};
    expected_methods = {'UIHtmlErrorLogger', 'delete', 'getStatus'};
    
    for i = 1:length(expected_methods)
        if any(strcmp(methods_list, expected_methods{i}))
            fprintf('✓ Method "%s" found\n', expected_methods{i});
        else
            fprintf('❌ Method "%s" missing\n', expected_methods{i});
        end
    end
    
    % Test 3: Check class properties
    fprintf('\nTest 3: Checking class properties...\n');
    properties_list = {metadata.PropertyList.Name};
    expected_properties = {'UIHtmlComponent', 'EventListener'};
    
    for i = 1:length(expected_properties)
        if any(strcmp(properties_list, expected_properties{i}))
            fprintf('✓ Property "%s" found\n', expected_properties{i});
        else
            fprintf('❌ Property "%s" missing\n', expected_properties{i});
        end
    end
    
    % Test 4: Test error handling for invalid input
    fprintf('\nTest 4: Testing error handling...\n');
    try
        % This should throw an error
        errorLogger = UIHtmlErrorLogger([]);
        fprintf('❌ Constructor should have thrown an error for invalid input\n');
    catch ME
        if contains(ME.identifier, 'UIHtmlErrorLogger:InvalidInput') || ...
           contains(ME.identifier, 'UIHtmlErrorLogger:MissingInput')
            fprintf('✓ Constructor properly handles invalid input\n');
            fprintf('  Error: %s\n', ME.message);
        else
            fprintf('⚠ Constructor threw unexpected error: %s\n', ME.message);
        end
    end
    
    fprintf('\n=== All syntax tests completed ===\n');
    
catch ME
    fprintf('❌ Error during testing: %s\n', ME.message);
    fprintf('   Stack trace:\n');
    for i = 1:length(ME.stack)
        fprintf('     %s (line %d)\n', ME.stack(i).name, ME.stack(i).line);
    end
end