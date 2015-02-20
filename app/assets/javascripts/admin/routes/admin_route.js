Discourse.AdminRoute = Discourse.Route.extend({
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
