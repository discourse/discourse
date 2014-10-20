/*global phantom:true */

console.log('Starting Smoke Test');
var system = require('system');

if(system.args.length !== 2) {
  console.log("expecting phantomjs {smoke_test.js} {base_url}");
  phantom.exit(1);
}

var page = require('webpage').create();

page.waitFor = function(desc, fn, timeout, after) {
  var check,start,promise;

  start = +new Date();
  promise = {};
  check = function() {
    var r;

    try {
      r = page.evaluate(fn);
    }
    catch(err) {
      // next time
    }

    var diff = (+new Date()) - start;

    if(r) {
      console.log("PASSED: " + desc + " " + diff + "ms" );
      after(true);
    } else {
      if(diff > timeout) {
        console.log("FAILED: " + desc + " " + diff + "ms");
        after(false);
      } else {
        setTimeout(check, 50);
      }
    }
  };

  check();
};


var actions = [];

var test = function(desc, fn) {
  actions.push({test: fn, desc: desc});
};

var navigate = function(desc, fn) {
  actions.push({navigate: fn, desc: desc});
};

var run = function(){
  var allPassed = true;
  var done = function() {
    if(allPassed) {
      console.log("ALL PASSED");
    } else {
      console.log("SMOKE TEST FAILED");
    }
    phantom.exit();
  };

  var performNextAction = function(){
    if(actions.length === 0) {
      done();
    }
    else{
      var action = actions[0];
      actions = actions.splice(1);
      if(action.test) {
        page.waitFor(action.desc, action.test, 10000, function(success){
          allPassed = allPassed && success;
          performNextAction();
        });
      }
      else if(action.navigate) {
        console.log("NAVIGATE: " + action.desc);
        page.evaluate(action.navigate);
        performNextAction();
      }
    }
  };

  performNextAction();
};

page.runTests = function(){

  test("at least one topic shows up", function() {
    return $('.topic-list tbody tr').length > 0;
  });

  test("expect a log in button", function(){
    return $('.login-button').text().trim() === 'Log In';
  });

  navigate("navigate to first topic", function(){
    Em.run.later(function(){
      if ($('.main-link > a:first').length > 0) {
        $('.main-link > a:first').click(); // topic list page
      } else {
        $('.featured-topic a.title:first').click(); // categories page
      }
    }, 500);
  });

  test("at least one post body", function(){
    return $('.topic-post').length > 0;
  });

  navigate("navigate to first user", function(){
    // for whatever reason the clicks do not respond at the begining
    //  defering
    Em.run.later(function(){

      // Remove the popup action for testing
      $('.topic-meta-data a:first').data('ember-action', '');

      $('.topic-meta-data a:first').focus().click();
    },500);
  });

  test("has details",function(){
    return $('#user-card .names').length === 1;
  });

  run();
};

page.open(system.args[1], function (status) {
    console.log("Opened " + system.args[1]);
    page.runTests();
});
