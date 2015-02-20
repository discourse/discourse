Discourse.AdminRoute = Discourse.Route.extend({
  renderTemplate: function() {
    this.render('admin/templates/admin');
  },

  titleToken: function() {
    return I18n.t('admin_title');
  },

  activate: function() {
    this._super();
    $("link.custom-css").attr("rel", "");
  },

  deactivate: function() {
    this._super();
    $("link.custom-css").attr("rel", "stylesheet");
  }
});
