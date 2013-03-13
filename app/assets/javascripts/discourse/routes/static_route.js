/**
  The routes used for rendering static content

  @class StaticRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.StaticController.pages.forEach(function(page) {

  Discourse[(page.capitalize()) + "Route"] = Discourse.Route.extend({
    renderTemplate: function() {
      this.render('static');
    },
    setupController: function() {
      this.controllerFor('static').loadPath("/" + page);
    }
  });

});


