Discourse.AdminCustomizeIndexRoute = Discourse.Route.extend({
  beforeModel: function() {
    this.replaceWith('adminCustomize.colors');
  }
});
