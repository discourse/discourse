(function() {

  Discourse.StaticController.pages.forEach(function(page) {
    window.Discourse["" + (page.capitalize()) + "Route"] = Discourse.Route.extend({
      renderTemplate: function() {
        return this.render('static');
      },
      setupController: function() {
        return this.controllerFor('static').loadPath("/" + page);
      }
    });
  });

}).call(this);
