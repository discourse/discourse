/**
  The routes used for rendering static content

  @class StaticRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.StaticController.PAGES.forEach(function(page) {
  Discourse[page.capitalize() + "Route"] = Discourse.Route.extend({

    renderTemplate: function() {
      this.render('static');
    },

    beforeModel: function(transition) {
      var configKey = Discourse.StaticController.CONFIGS[page];
      if (configKey && Discourse.SiteSettings[configKey].length > 0) {
        transition.abort();
        Discourse.URL.redirectTo(Discourse.SiteSettings[configKey]);
      }
    },

    model: function() {
      return Discourse.StaticPage.find(page);
    },

    setupController: function(controller, model) {
      this.controllerFor('static').set('model', model);
    }
  });
});
