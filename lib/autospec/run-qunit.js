/*jshint devel:true, phantom:true */
/*globals QUnit ANSI */

// THIS FILE IS CALLED BY "qunit_runner.rb" IN AUTOSPEC

var system = require("system"),
    args = phantom.args;

if (args === undefined) {
  args = system.args;
  args.shift();
}

if (args.length !== 1) {
  console.log("Usage: " + phantom.scriptName + " <URL>");
  phantom.exit(1);
}

var fs = require('fs'),
    page = require('webpage').create(),
    QUNIT_RESULT = "./tmp/qunit_result";

if (fs.exists(QUNIT_RESULT) && fs.isFile(QUNIT_RESULT)) { fs.remove(QUNIT_RESULT); }

page.onConsoleMessage = function (message) {
  // filter out Ember's debug messages
  if (message.slice(0, 8) === "WARNING:") { return; }
  if (message.slice(0, 6) === "DEBUG:") { return; }

  console.log(message);
};

page.onCallback = function (message) {
  // write to the result file
  if (message.slice(0, 5) === "FILE:") { fs.write(QUNIT_RESULT, message.slice(6), "a"); }
  // forward the message to the standard output
  if (message.slice(0, 6) === "PRINT:") { system.stdout.write(message.slice(7)); }
};

page.start = new Date();

// -----------------------------------WARNING --------------------------------------
// calling "console.log" BELOW this line will go through the "page.onConsoleMessage"
// -----------------------------------WARNING --------------------------------------
page.open(args[0], function (status) {
  if (status !== "success") {
    console.log("\nNO NETWORK :(\n");
    phantom.exit(1);
  } else {
    console.log("QUnit loaded in " + (new Date() - page.start) + " ms");

    page.evaluate(colorizer);
    page.evaluate(logQUnit);

    // wait up to 60 seconds for QUnit to finish
    var timeout = 60 * 1000,
        start = Date.now();

    var interval = setInterval(function() {
      if (Date.now() - start > timeout) {
        console.error("\nTIME OUT :(\n");
        phantom.exit(1);
      } else {
        var qunitResult = page.evaluate(function() { return window.qunitResult; });
        if (qunitResult) {
          clearInterval(interval);
          if (qunitResult.failed > 0) {
            phantom.exit(1);
          } else {
            phantom.exit(0);
          }
        }
      }
    }, 250);
  }
});

// https://github.com/jquery/qunit/pull/470
function colorizer() {
  window.ANSI = {
    colorMap: {
      "red": "\u001b[31m",
      "green": "\u001b[32m",
      "blue": "\u001b[34m",
      "end": "\u001b[0m"
    },
    highlightMap: {
      "red": "\u001b[41m\u001b[37m", // change 37 to 30 for black text
      "green": "\u001b[42m\u001b[30m",
      "blue": "\u001b[44m\u001b[37m",
      "end": "\u001b[0m"
    },

    highlight: function (text, color) {
      var colorCode = this.highlightMap[color],
          colorEnd = this.highlightMap.end;

      return colorCode + text + colorEnd;
    },

    colorize: function (text, color) {
      var colorCode = this.colorMap[color],
          colorEnd = this.colorMap.end;

      return colorCode + text + colorEnd;
    }
  };
}


function logQUnit() {
  // keep track of error messages
  var errors = {};

  QUnit.begin(function () {
    console.log("BEGIN");
  });

  QUnit.log(function (context) {
    if (!context.result) {
      var module = context.module,
          test = context.name;

      var assertion = {
        message: context.message,
        expected: context.expected,
        actual: context.actual
      };

      if (!errors[module]) { errors[module] = {}; }
      if (!errors[module][test]) { errors[module][test] = []; }
      errors[module][test].push(assertion);

      var fileName = context.source
                            .replace(/[^\S\n]+at[^\S\n]+/g, "")
                            .split("\n")[1]
                            .replace(/\?.+$/, "")
                            .replace(/^.+\/assets\//, "test/javascripts/");
      window.callPhantom("FILE: " + fileName + " ");
    }
  });

  QUnit.testDone(function (context) {
    if (context.failed > 0) {
      window.callPhantom("PRINT: " + ANSI.colorize("F", "red"));
    } else {
      window.callPhantom("PRINT: " +  ANSI.colorize(".", "green"));
    }
  });

  QUnit.done(function (context) {
    console.log("\n");

    // display failures
    if (Object.keys(errors).length > 0) {
      console.log("Failures:\n");
      for (var m in errors) {
        var module = errors[m];
        console.log("Module Failed: " + ANSI.highlight(m, "red"));
        for (var t in module) {
          var test = module[t];
          console.log("  Test Failed: " + t);
          for (var a = 0; a < test.length; a++) {
            var assertion = test[a];
            console.log("    Assertion Failed: " + (assertion.message || ""));
            if (assertion.expected) {
              console.log("      Expected: " + assertion.expected);
              console.log("        Actual: " + assertion.actual);
            }
          }
        }
      }
    }

    // display summary
    console.log("\n");
    console.log("Finished in " + (context.runtime / 1000) + " seconds");
    var color = context.failed > 0 ? "red" : "green";
    console.log(ANSI.colorize(context.total + " examples, " + context.failed + " failures", color));

    // we're done
    window.qunitResult = context;
  });

}
