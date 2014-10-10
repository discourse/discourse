export default Discourse.Route.extend({
  model: function() {
    return Discourse.ajax("/about.json").then(function(result) {
      return result.about;
    });
  },

  titleToken: function() {
    return I18n.t('about.simple_title');
  }
});
