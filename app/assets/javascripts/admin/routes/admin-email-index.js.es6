import EmailSettings from 'admin/models/email-settings';

export default Discourse.Route.extend({
  model: function() {
    return EmailSettings.find();
  },

  renderTemplate: function() {
    this.render('admin/templates/email_index', { into: 'adminEmail' });
  }
});
