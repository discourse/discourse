/**
  The routes used for rendering pages content

  @class PagesRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.PagesController.pages.forEach(function(page) {

  Discourse[(page.capitalize()) + "Route"] = Discourse.Route.extend({
    renderTemplate: function() {
      this.render('pages');
    },
    setupController: function() {
      this.controllerFor('pages').loadPage("/pages/" + page);
    }
  });

});

Discourse["PagesRoute"] = Discourse.Route.extend({
  renderTemplate: function() {
    this.render('pages');
  },
  setupController: function() {
    this.controllerFor('pages').loadPage("/pages");
  }
});
