// Chrome QUnit Test Runner
// Author: David Taylor
// Requires chrome-launcher and chrome-remote-interface from npm
// An up-to-date version of chrome is also required

var args = process.argv.slice(2);

if (args.length < 1 || args.length > 2) {
  console.log("Usage: node run-qunit-chrome.js <URL> <timeout>");
  process.exit(1);
}

const chromeLauncher = require('chrome-launcher');
const CDP = require('chrome-remote-interface');

(async function() {

  async function launchChrome() {
    return await chromeLauncher.launch({
      chromeFlags: [
        '--disable-gpu',
        '--headless'
      ]
    });
  }
  const chrome = await launchChrome();
  const protocol = await CDP({
    port: chrome.port
  });

  const {
    Page,
    Runtime
  } = protocol;
  await Page.enable();
  await Runtime.enable();

  Runtime.consoleAPICalled((response) => {
    const message = response['args'][0].value;

    // If it's a simple test result, write without newline
    if(message === "." || message === "F"){
      process.stdout.write(message);
    }else{
      console.log(message);
    }
  });

  Page.navigate({
    url: args[0]
  });

  Page.loadEventFired(async() => {
    
    await Runtime.evaluate({
      expression: `(${qunit_script})()`
    });
    
    const timeout = parseInt(args[1] || 300000, 10);
    var start = Date.now();

    var interval = setInterval(async() => {
      if (Date.now() > start + timeout) {
        console.error("Tests timed out");

        protocol.close();
        chrome.kill(); 
        process.exit(124);
      } else {
        
        const numFails = await Runtime.evaluate({
          expression: `(${check_script})()`
        });

        if (numFails.result.type !== 'undefined') {
          clearInterval(interval);
          protocol.close();
          chrome.kill(); 

          if (numFails.value > 0) {
            process.exit(1);
          } else {
            process.exit();
          }
        }
      }
    }, 250);

  });

})();

// The following functions are converted to strings
// And then sent to chrome to be evalaluated
function logQUnit() {
  var moduleErrors = [];
  var testErrors = [];
  var assertionErrors = [];

  console.log("\nRunning: " + JSON.stringify(QUnit.urlParams) + "\n");

  QUnit.config.testTimeout = 10000;

  QUnit.moduleDone(function(context) {
    if (context.failed) {
      var msg = "Module Failed: " + context.name + "\n" + testErrors.join("\n");
      moduleErrors.push(msg);
      testErrors = [];
    }
  });

  QUnit.testDone(function(context) {
    if (context.failed) {
      var msg = "  Test Failed: " + context.name + assertionErrors.join("    ");
      testErrors.push(msg);
      assertionErrors = [];
      console.log("F");
    } else {
      console.log(".");
    }
  });

  QUnit.log(function(context) {
    if (context.result) { return; }

    var msg = "\n    Assertion Failed:";
    if (context.message) {
      msg += " " + context.message;
    }

    if (context.expected) {
      msg += "\n      Expected: " + context.expected + ", Actual: " + context.actual;
    }

    assertionErrors.push(msg);
  });

  QUnit.done(function(context) {
    console.log("\n");

    if (moduleErrors.length > 0) {
      for (var idx=0; idx<moduleErrors.length; idx++) {
        console.error(moduleErrors[idx]+"\n");
      }
    }

    var stats = [
      "Time: " + context.runtime + "ms",
      "Total: " + context.total,
      "Passed: " + context.passed,
      "Failed: " + context.failed
    ];
    console.log(stats.join(", "));
    window.qunitDone = context;
  });
}
const qunit_script = logQUnit.toString();

function check() {
  if(window.qunitDone){
    return window.qunitDone.failed;
  }
}
const check_script = check.toString();