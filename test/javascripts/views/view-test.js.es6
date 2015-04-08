import Presence from 'discourse/mixins/presence';

var oldHelpers;

module("Discourse.View", {
  setup: function() {
    oldHelpers = Ember.Handlebars.helpers;
  },

  teardown: function() {
    Ember.Handlebars.helpers = oldHelpers;
  }
});

test("mixes in Presence", function() {
  ok(Presence.detect(Discourse.View.create()));
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
