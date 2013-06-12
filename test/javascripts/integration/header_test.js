module("Header", {
  setup: function() {
    Ember.run(Discourse, Discourse.advanceReadiness);
  },

  teardown: function() {
    $('#discourse-modal').modal('hide')
    $('#discourse-modal').remove()
    Discourse.reset();
  }
});

test("/", function() {
  expect(2);

  visit("/").then(function() {
    ok(exists("header"), "The header was rendered");
    ok(exists("#site-logo"), "The logo was shown");
  });

});


