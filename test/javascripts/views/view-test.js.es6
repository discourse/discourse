var oldHelpers;

module("Discourse.View", {
  setup: function() {
    oldHelpers = Ember.Handlebars.helpers;
  },

  teardown: function() {
    Ember.Handlebars.helpers = oldHelpers;
  }
});

test("mixes in Discourse.Presence", function() {
  ok(Discourse.Presence.detect(Discourse.View.create()));
});

test("registerHelper: enables embedding a child view in a parent view via dedicated, named helper instead of generic 'view' helper", function() {
  Discourse.View.registerHelper("childViewHelper", Ember.View.extend({
    template: Ember.Handlebars.compile('{{view.text}}')
  }));

  var parentView = Ember.View.extend({
    template: Ember.Handlebars.compile('{{childViewHelper id="child" text="foo"}}')
  }).create();

  Ember.run(function() {
    parentView.appendTo("#qunit-fixture");
  });

  equal(parentView.$("#child").length, 1, "child view registered as helper is appended to the parent view");
  equal(parentView.$("#child").text(), "foo", "child view registered as helper gets parameters provided during helper invocation in parent's template");
});

test("renderIfChanged: rerenders the whole view template when one of registered view fields changes", function() {
  var view, rerenderSpy;

  var viewRerendersOnceWhen = function(message, changeCallback) {
    rerenderSpy.reset();
    Ember.run(function() { changeCallback(); });
    ok(rerenderSpy.calledOnce, "view rerenders when " + message);
  };

  var viewDoesNotRerenderWhen = function(message, changeCallback) {
    rerenderSpy.reset();
    Ember.run(function() { changeCallback(); });
    ok(!rerenderSpy.called, "view does not rerender when " + message);
  };


  view = Ember.View.extend({
    shouldRerender: Discourse.View.renderIfChanged("simple", "complex.@each.nested")
  }).create({
    simple: "initial value",
    complex: [Ember.Object.create({nested: "initial value"})],
    unregistered: "initial value"
  });

  rerenderSpy = sinon.spy(view, "rerender");

  Ember.run(function() {
    view.appendTo("#qunit-fixture");
  });


  viewRerendersOnceWhen("a simple field (holding a string) changes", function() {
    view.set("simple", "updated value");
  });

  viewRerendersOnceWhen("a nested sub-field of a complex field (holding an array of objects) changes", function() {
    view.get("complex").objectAt(0).set("nested", "updated value");
  });

  viewDoesNotRerenderWhen("unregistered field changes", function() {
    view.set("unregistered", "updated value");
  });
});
