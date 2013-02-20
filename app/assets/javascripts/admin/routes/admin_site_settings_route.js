(function() {

  Discourse.AdminSiteSettingsRoute = Discourse.Route.extend({
    model: function() {
      return Discourse.SiteSetting.findAll();
    }
  });

}).call(this);
