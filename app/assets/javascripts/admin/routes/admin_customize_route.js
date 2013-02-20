(function() {

  Discourse.AdminCustomizeRoute = Discourse.Route.extend({
    model: function() {
      return Discourse.SiteCustomization.findAll();
    }
  });

}).call(this);
