// Karma configuration
// Generated on Fri Jun 21 2013 16:07:05 GMT-0500 (Central Daylight Time)


// base path, that will be used to resolve files and exclude
basePath = '';


frameworks=[
  'jasmine'
];

// list of files / patterns to load in the browser
files = [
//  JASMINE,
//  JASMINE_ADAPTER,
  'http://code.jquery.com/jquery-1.9.1.js',
  'http://code.angularjs.org/1.0.6/angular.js',
  'http://code.angularjs.org/1.0.6/angular-mocks.js',
  'public/scripts/**/*.js',
  'test/**/*Spec.js'
];


// list of files to exclude
exclude = [
  
];


// test results reporter to use
// possible values: 'dots', 'progress', 'junit'
reporters = ['progress'];


// web server port
port = 9876;


// cli runner port
runnerPort = 9100;


// enable / disable colors in the output (reporters and logs)
colors = false;


// level of logging
// possible values: LOG_DISABLE || LOG_ERROR || LOG_WARN || LOG_INFO || LOG_DEBUG
//logLevel = require('karma').LOG_INFO;


// enable / disable watching file and executing tests whenever any file changes
autoWatch = true;


// Start these browsers, currently available:
// - Chrome
// - ChromeCanary
// - Firefox
// - Opera
// - Safari (only Mac)
// - PhantomJS
// - IE (only Windows)
//browsers = ['Chrome','IE'];
browsers = ['Chrome'];
//browsers = ['IE'];


// If browser does not capture in given timeout [ms], kill it
captureTimeout = 60000;


// Continuous Integration mode
// if true, it capture browsers, run tests and exit
singleRun = false;
