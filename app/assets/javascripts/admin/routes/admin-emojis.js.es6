export default Discourse.Route.extend({
  model: function() {
    return Discourse.ajax("/admin/customize/emojis.json").then(function(emojis) {
      return emojis.map(function (emoji) { return Ember.Object.create(emoji); });
    });
  }
});
