function integration(name) {
  module(name, {
    setup: function() {
      Ember.run(Discourse, Discourse.advanceReadiness);
    },

    teardown: function() {
      Discourse.reset();
    }
  });
}