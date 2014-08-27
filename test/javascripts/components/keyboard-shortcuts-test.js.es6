var testMouseTrap;

module("Discourse.KeyboardShortcuts", {
  setup: function() {
    var _bindings = {};

    testMouseTrap = {
      bind: function(bindings, callback) {
        var registerBinding = _.bind(function(binding) {
          _bindings[binding] = callback;
        }, this);

        if (_.isArray(bindings)) {
          _.each(bindings, registerBinding, this);
        }
        else {
          registerBinding(bindings);
        }
      },

      trigger: function(binding) {
        _bindings[binding].call();
      }
    };

    sandbox.stub(Discourse.URL, "routeTo");

    $("#qunit-fixture").html([
      "<article class='topic-post selected'>",
      "<a class='post-date'></a>" +
      "</article>",
      "<div class='notification-options'>",
      "  <ul>",
      "    <li data-id='0'><a></a></li>",
      "    <li data-id='1'><a></a></li>",
      "    <li data-id='2'><a></a></li>",
      "    <li data-id='3'><a></a></li>",
      "  </ul>",
      "</div>",
      "<table class='topic-list'>",
      "  <tr class='topic-list-item selected'><td>",
      "    <a class='title'></a>",
      "  </td></tr>",
      "</table>",
      "<div id='topic-footer-buttons'>",
      "  <button class='star'></button>",
      "  <button class='create'></button>",
      "  <button class='share'></button>",
      "</div>",
      "<button id='create-topic'></button>",
      "<div id='user-notifications'></div>",
      "<div id='site-map'></div>",
      "<div id='search-button'></div>",
      "<div id='current-user'></div>",
      "<div id='keyboard-help'></div>"
    ].join("\n"));
  },

  teardown: function() {
    $("#qunit-scratch").html("");
  }
});

var pathBindings = Discourse.KeyboardShortcuts.PATH_BINDINGS;

_.each(pathBindings, function(path, binding) {
  var testName = binding + " goes to " + path;

  test(testName, function() {
    Discourse.KeyboardShortcuts.bindEvents(testMouseTrap);
    testMouseTrap.trigger(binding);

    ok(Discourse.URL.routeTo.calledWith(path));
  });
});

var clickBindings = Discourse.KeyboardShortcuts.CLICK_BINDINGS;

_.each(clickBindings, function(selector, binding) {
  var bindings = binding.split(",");

  var testName = binding + " clicks on " + selector;

  test(testName, function() {
    Discourse.KeyboardShortcuts.bindEvents(testMouseTrap);
    $(selector).on("click", function() {
      ok(true, selector + " was clicked");
    });

    _.each(bindings, function(binding) {
      testMouseTrap.trigger(binding);
    }, this);
  });
});

var functionBindings = Discourse.KeyboardShortcuts.FUNCTION_BINDINGS;

_.each(functionBindings, function(func, binding) {
  var testName = binding + " calls " + func;

  test(testName, function() {
    sandbox.stub(Discourse.KeyboardShortcuts, func, function() {
      ok(true, func + " is called when " + binding + " is triggered");
    });
    Discourse.KeyboardShortcuts.bindEvents(testMouseTrap);

    testMouseTrap.trigger(binding);
  });
});

test("selectDown calls _moveSelection with 1", function() {
  var spy = sandbox.spy(Discourse.KeyboardShortcuts, '_moveSelection');

  Discourse.KeyboardShortcuts.selectDown();
  ok(spy.calledWith(1), "_moveSelection is called with 1");
});

test("selectUp calls _moveSelection with -1", function() {
  var spy = sandbox.spy(Discourse.KeyboardShortcuts, '_moveSelection');

  Discourse.KeyboardShortcuts.selectUp();
  ok(spy.calledWith(-1), "_moveSelection is called with -1");
});

test("goBack calls history.back", function() {
  var called = false;
  sandbox.stub(history, 'back', function() {
    called = true;
  });

  Discourse.KeyboardShortcuts.goBack();
  ok(called, "history.back is called");
});

test("nextSection calls _changeSection with 1", function() {
  var spy = sandbox.spy(Discourse.KeyboardShortcuts, '_changeSection');

  Discourse.KeyboardShortcuts.nextSection();
  ok(spy.calledWith(1), "_changeSection is called with 1");
});

test("prevSection calls _changeSection with -1", function() {
  var spy = sandbox.spy(Discourse.KeyboardShortcuts, '_changeSection');

  Discourse.KeyboardShortcuts.prevSection();
  ok(spy.calledWith(-1), "_changeSection is called with -1");
});
