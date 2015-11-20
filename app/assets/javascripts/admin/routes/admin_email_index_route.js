Discourse.AdminEmailIndexRoute = Discourse.Route.extend({
  model: function() {
    return Discourse.EmailSettings.find();
  },

  renderTemplate: function() {
    this.render('admin/templates/email_index', { into: 'adminEmail' });
  }
});
