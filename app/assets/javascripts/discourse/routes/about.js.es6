export default Ember.Route.extend({
  model: function() {
    return Discourse.ajax("/about.json").then(function(result) {
      return result.about;
    });
  }
});

