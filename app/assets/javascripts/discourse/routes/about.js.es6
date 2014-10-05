export default Discourse.Route.extend({
  model: function() {
    return Discourse.ajax("/about.json").then(function(result) {
      return result.about;
    });
  },

  setupController: function(controller, model) {
    controller.set('model', model);
    Discourse.set('title', I18n.t('about.simple_title'));
  }
});

