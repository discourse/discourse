Discourse.AdminCustomizeCssHtmlRoute = Discourse.Route.extend({
  model: function() {
    return Discourse.SiteCustomization.findAll();
  }
});
