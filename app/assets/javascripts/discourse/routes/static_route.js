/**
  The routes used for rendering static content

  @class StaticRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
_.each(Discourse.StaticController.PAGES, function(page) {

  Discourse[page.capitalize() + "Route"] = Discourse.Route.extend({

    renderTemplate: function() {
      this.render('static');
    },

    setupController: function() {
      var config_key = Discourse.StaticController.CONFIGS[page];
      if (config_key && Discourse.SiteSettings[config_key].length > 0) {
        Discourse.URL.redirectTo(Discourse.SiteSettings[config_key]);
      } else {
        this.controllerFor('static').loadPath("/" + page);
      }
    }

  });

});
