/*global phantom:true */

console.log("Starting Discourse Smoke Test");

var system = require("system");

if (system.args.length !== 2) {
  console.log("Expecting: phantomjs {smoke_test.js} {url}");
  phantom.exit(1);
}

var TIMEOUT = 15000;
var page = require("webpage").create();

page.viewportSize = {
  width: 1366,
  height: 768
};

// In the browser, when the cookies are disabled, it also disables the localStorage
// Here, we're mocking that behavior and making sure the application doesn't blow up
page.onInitialized = function() {
  page.evaluate(function() {
    localStorage["disableLocalStorage"] = true;
  });
};

page.onConsoleMessage = function(msg) {
  console.log(msg);
}

page.waitFor = function(desc, fn, cb) {
  var start = +new Date();

  var check = function() {
    var r;

    try { r = page.evaluate(fn); } catch (err) { }

    var diff = (+new Date()) - start;

    if (r) {
      console.log("PASSED: " + desc + " - " + diff + "ms");
      cb(true);
    } else {
      if (diff > TIMEOUT) {
        console.log("FAILED: " + desc + " - " + diff + "ms");
        page.render('/tmp/failed.png');
        cb(false);
      } else {
        setTimeout(check, 25);
      }
    }
  };

  check();
};


var actions = [];

function test(desc, fn) {
  actions.push({ test: fn, desc: desc });
};

function wait(delay) {
  actions.push({ wait: delay });
}

function exec(desc, fn) {
  actions.push({ exec: fn, desc: desc });
};

function execAsync(desc, delay, fn) {
  actions.push({ execAsync: fn, delay: delay, desc: desc });
};

function upload(input, path) {
  actions.push({ upload: path, input: input });
};

function screenshot(filename) {
  actions.push({ screenshot: filename });
}

function run() {
  var allPassed = true;

  var done = function() {
    console.log(allPassed ? "ALL PASSED" : "SMOKE TEST FAILED");
    phantom.exit();
  };

  var performNextAction = function() {
    if (!allPassed || actions.length === 0) {
      done();
    } else {
      var action = actions[0];
      actions = actions.splice(1);
      if (action.test) {
        page.waitFor(action.desc, action.test, function(success) {
          allPassed = allPassed && success;
          performNextAction();
        });
      } else if (action.exec) {
        console.log("EXEC: " + action.desc);
        page.evaluate(action.exec);
        performNextAction();
      } else if (action.execAsync) {
        console.log("EXEC ASYNC: " + action.desc + " - " + action.delay + "ms");
        setTimeout(function() {
          page.evaluate(action.execAsync);
          performNextAction();
        }, action.delay);
      } else if (action.upload) {
        console.log("UPLOAD: " + action.upload);
        page.uploadFile(action.input, action.upload);
        performNextAction();
      } else if (action.screenshot) {
        console.log("SCREENSHOT: " + action.screenshot);
        page.render(action.screenshot);
        performNextAction();
      } else if (action.wait) {
        console.log("WAIT: " + action.wait + "ms");
        setTimeout(function() {
          performNextAction();
        }, action.wait);
      }
    }
  };

  performNextAction();
};

var runTests = function() {

  test("expect a log in button", function() {
    return $(".login-button").text().trim() === "Log In";
  });

  test("at least one topic shows up", function() {
    return document.querySelector(".topic-list tbody tr");
  });

  execAsync("navigate to 1st topic", 500, function() {
    if ($(".main-link > a:first").length > 0) {
      $(".main-link > a:first").click(); // topic list page
    } else {
      $(".featured-topic a.title:first").click(); // categories page
    }
  });

  test("at least one post body", function() {
    return document.querySelector(".topic-post");
  });

  execAsync("click on the 1st user", 500, function() {
    // remove the popup action for testing
    $(".topic-meta-data a:first").data("ember-action", "");
    $(".topic-meta-data a:first").focus().click();
  });

  test("user has details", function() {
    return document.querySelector("#user-card .names");
  });

  exec("open login modal", function() {
    $(".login-button").click();
  });

  test("login modal is open", function() {
    return document.querySelector(".login-modal");
  });

  exec("type in credentials & log in", function() {
    $("#login-account-name").val("smoke_user").trigger("change");
    $("#login-account-password").val("P4ssw0rd").trigger("change");
    $(".login-modal .btn-primary").click();
  });

  test("is logged in", function() {
    return document.querySelector(".current-user");
  });

  exec("go home", function() {
    $('#site-logo').click();
  });

  test("it shows a topic list", function() {
    return document.querySelector(".topic-list");
  });

  test('we have a create topic button', function() {
    return document.querySelector("#create-topic");
  });

  exec("open composer", function() {
    $("#create-topic").click();
  });

  test('the editor is visible', function() {
    return document.querySelector(".d-editor");
  });

  exec("compose new topic", function() {
    var date = " (" + (+new Date()) + ")",
        title = "This is a new topic" + date,
        post = "I can write a new topic inside the smoke test!" + date + "\n\n";

    $("#reply-title").val(title).trigger("change");
    $("#reply-control .d-editor-input").val(post).trigger("change");
    $("#reply-control .d-editor-input").focus()[0].setSelectionRange(post.length, post.length);
  });

  test("updates preview", function() {
    return document.querySelector(".d-editor-preview p");
  });

  exec("open upload modal", function() {
    $(".d-editor-button-bar .upload").click();
  });

  test("upload modal is open", function() {
    return document.querySelector("#filename-input");
  });

  // TODO: Looks like PhantomJS 2.0.0 has a bug with `uploadFile`
  // which breaks this code.

  // upload("#filename-input", "spec/fixtures/images/large & unoptimized.png");
  // test("the file is inserted into the input", function() {
  //   return document.getElementById('filename-input').files.length
  // });
  // screenshot('/tmp/upload-modal.png');
  //
  // test("upload modal is open", function() {
  //   return document.querySelector("#filename-input");
  // });
  //
  // exec("click upload button", function() {
  //   $(".modal .btn-primary").click();
  // });
  //
  // test("image is uploaded", function() {
  //   return document.querySelector(".cooked img");
  // });

  exec("submit the topic", function() {
    $("#reply-control .create").click();
  });

  test("topic is created", function() {
    return document.querySelector(".fancy-title");
  });

  exec("click reply button", function() {
    $(".post-controls:first .create").click();
  });

  test("composer is open", function() {
    return document.querySelector("#reply-control .d-editor-input");
  });

  exec("compose reply", function() {
    var post = "I can even write a reply inside the smoke test ;) (" + (+new Date()) + ")";
    $("#reply-control .d-editor-input").val(post).trigger("change");
  });

  test("waiting for the preview", function() {
    return $(".d-editor-preview").text().trim().indexOf("I can even write") === 0;
  });

  execAsync("submit the reply", 6000, function() {
    $("#reply-control .create").click();
  });

  test("reply is created", function() {
    return !document.querySelector(".saving-text")
        && $(".topic-post").length === 2;
  });

  run();
};

phantom.clearCookies();
page.open(system.args[1], function() {
  page.evaluate(function() { localStorage.clear(); });
  console.log("OPENED: " + system.args[1]);
  runTests();
});
