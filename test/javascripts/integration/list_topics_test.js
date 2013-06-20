/*global module:true test:true ok:true visit:true expect:true exists:true count:true */

module("List Topics", {
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

    ok(exists("#topic-list"), "The list of topics was rendered");
    ok(count('#topic-list .topic-list-item') > 0, "has topics");
  });

});


