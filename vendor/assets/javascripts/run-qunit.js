// Chrome QUnit Test Runner
// Author: David Taylor
// Requires chrome-launcher and chrome-remote-interface from npm
// An up-to-date version of chrome is also required

/* globals Promise */

var args = process.argv.slice(2);

if (args.length < 1 || args.length > 3) {
  console.log("Usage: node run-qunit.js <URL> <timeout> <result_file>");
  process.exit(1);
}

const chromeLauncher = require('chrome-launcher');
const CDP = require('chrome-remote-interface');

const QUNIT_RESULT = args[2];
const fs = require('fs');

if (QUNIT_RESULT) {
  (async () => {
    await fs.stat(QUNIT_RESULT, (err, stats) => {
      if (stats && stats.isFile()) fs.unlink(QUNIT_RESULT);
    });
  })();
}

async function runAllTests() {

  function launchChrome() {
    const options = {
      chromeFlags: [
        '--disable-gpu',
       '--headless',
       '--no-sandbox'
      ]
    };

    if (process.env.REMOTE_DEBUG) {
      options.port = 9222;
    }

    return chromeLauncher.launch(options);
  }

  let chrome = await launchChrome();
  let protocol = await CDP({ port: chrome.port});

  const {Page, Runtime} = protocol;

  await Promise.all([Page.enable(), Runtime.enable()]);

  Runtime.consoleAPICalled((response) => {
    const message = response['args'][0].value;

    // If it's a simple test result, write without newline
    if(message === "." || message === "F"){
      process.stdout.write(message);
    } else if (message && message.startsWith("AUTOSPEC:")) {
      fs.appendFileSync(QUNIT_RESULT, `${message.slice(10)}\n`);
    } else {
      console.log(message);
    }
  });

  console.log("navigate to " + args[0]);
  Page.navigate({url: args[0]});

  Page.loadEventFired(async () => {

    await Runtime.evaluate({ expression: `(${qunit_script})()`});

    const timeout = parseInt(args[1] || 300000, 10);
    var start = Date.now();

    var interval;

    let runTests = async function() {
      if (Date.now() > start + timeout) {
        console.error("Tests timed out");
        protocol.close();
        chrome.kill();
        process.exit(124);
      }

      let numFails = await Runtime.evaluate({expression: `(${check_script})()`});

      if (numFails && numFails.result && numFails.result.type !== 'undefined') {
        clearInterval(interval);
        protocol.close();
        chrome.kill();

        if (numFails.result.value > 0) {
          process.exit(1);
        } else {
          process.exit();
        }
      }
    };

    interval = setInterval(runTests, 250);
  });

}

try {
  runAllTests();
} catch(e) {
  console.log("Failed to run tests: " + e);
  process.exit(1);
}

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

  let durations = {};

  QUnit.testDone(function(context) {

    durations[context.module + "::" + context.name] = context.runtime;

    if (context.failed) {
      var msg = "  Test Failed: " + context.name + assertionErrors.join("    ");

      /* QUNIT_RESULT */

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

    console.log("Slowest tests");
    console.log("----------------------------------------------");
    let ary = Object.keys(durations).map((key) => ({ 'key': key, 'value': durations[key] }))
    ary.sort((p1, p2) => (p2.value - p1.value));
    ary.slice(0, 30).forEach(pair => {
      console.log(pair.key + ": " + pair.value + "ms");
    });

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
let qunit_script = logQUnit.toString();

if (QUNIT_RESULT) {
  qunit_script = qunit_script.replace("/* QUNIT_RESULT */", "console.log(`AUTOSPEC: ${context.module}:::${context.testId}:::${context.name}`);");

}

function check() {
  if(window.qunitDone){
    return window.qunitDone.failed;
  }
}

const check_script = check.toString();
