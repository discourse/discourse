/*global module:true test:true ok:true visit:true expect:true exists:true count:true */

module("Header", {
  setup: function() {
    Ember.run(Discourse, Discourse.advanceReadiness);
  },

  teardown: function() {
    Discourse.reset();
  }
});

test("/", function() {

  visit("/").then(function() {
    expect(2);

    ok(exists("header"), "The header was rendered");
    ok(exists("#site-logo"), "The logo was shown");
  });

});


