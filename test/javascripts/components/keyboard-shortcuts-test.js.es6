import DiscourseURL from "discourse/lib/url";

var testMouseTrap;
import KeyboardShortcuts from "discourse/lib/keyboard-shortcuts";

QUnit.module("lib:keyboard-shortcuts", {
  beforeEach() {
    var _bindings = {};

    testMouseTrap = {
      bind: function(bindings, callback) {
        var registerBinding = _.bind(function(binding) {
          _bindings[binding] = callback;
        }, this);

        if (_.isArray(bindings)) {
          bindings.forEach(registerBinding, this);
        } else {
          registerBinding(bindings);
        }
      },

      trigger: function(binding) {
        _bindings[binding].call();
      }
    };

    sandbox.stub(DiscourseURL, "routeTo");

    $("#qunit-fixture").html(
      [
        "<article class='topic-post selected'>",
        "<a class='post-date'></a>" + "</article>",
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
        "  <button id='dismiss-new-top'></button>",
        "  <button id='dismiss-topics-top'></button>",
        "</div>",
        "<div class='alert alert-info clickable'></div>",
        "<button id='create-topic'></button>",
        "<div id='user-notifications'></div>",
        "<div id='toggle-hamburger-menu'></div>",
        "<div id='search-button'></div>",
        "<div id='current-user'></div>",
        "<div id='keyboard-help'></div>"
      ].join("\n")
    );
  },

  afterEach() {
    $("#qunit-scratch").html("");
  }
});

var pathBindings = KeyboardShortcuts.PATH_BINDINGS || {};
Object.keys(pathBindings).forEach(path => {
  const binding = pathBindings[path];
  var testName = binding + " goes to " + path;

  test(testName, function(assert) {
    KeyboardShortcuts.bindEvents(testMouseTrap, Discourse.__container__);
    testMouseTrap.trigger(binding);

    assert.ok(DiscourseURL.routeTo.calledWith(path));
  });
});

var clickBindings = KeyboardShortcuts.CLICK_BINDINGS || {};
Object.keys(clickBindings).forEach(selector => {
  const binding = clickBindings[selector];
  var bindings = binding.split(",");

  var testName = binding + " clicks on " + selector;

  test(testName, function(assert) {
    KeyboardShortcuts.bindEvents(testMouseTrap, Discourse.__container__);
    $(selector).on("click", function() {
      assert.ok(true, selector + " was clicked");
    });

    bindings.forEach(function(b) {
      testMouseTrap.trigger(b);
    }, this);
  });
});

var functionBindings = KeyboardShortcuts.FUNCTION_BINDINGS || {};
Object.keys(functionBindings).forEach(func => {
  const binding = functionBindings[func];
  var testName = binding + " calls " + func;

  test(testName, function(assert) {
    sandbox.stub(KeyboardShortcuts, func, function() {
      assert.ok(true, func + " is called when " + binding + " is triggered");
    });
    KeyboardShortcuts.bindEvents(testMouseTrap, Discourse.__container__);

    testMouseTrap.trigger(binding);
  });
});

QUnit.test("selectDown calls _moveSelection with 1", assert => {
  var stub = sandbox.stub(KeyboardShortcuts, "_moveSelection");

  KeyboardShortcuts.selectDown();
  assert.ok(stub.calledWith(1), "_moveSelection is called with 1");
});

QUnit.test("selectUp calls _moveSelection with -1", assert => {
  var stub = sandbox.stub(KeyboardShortcuts, "_moveSelection");

  KeyboardShortcuts.selectUp();
  assert.ok(stub.calledWith(-1), "_moveSelection is called with -1");
});

QUnit.test("goBack calls history.back", assert => {
  var called = false;
  sandbox.stub(history, "back").callsFake(function() {
    called = true;
  });

  KeyboardShortcuts.goBack();
  assert.ok(called, "history.back is called");
});

QUnit.test("nextSection calls _changeSection with 1", assert => {
  var spy = sandbox.spy(KeyboardShortcuts, "_changeSection");

  KeyboardShortcuts.nextSection();
  assert.ok(spy.calledWith(1), "_changeSection is called with 1");
});

QUnit.test("prevSection calls _changeSection with -1", assert => {
  var spy = sandbox.spy(KeyboardShortcuts, "_changeSection");

  KeyboardShortcuts.prevSection();
  assert.ok(spy.calledWith(-1), "_changeSection is called with -1");
});
