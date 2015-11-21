const EmailSettings = Discourse.Model.extend({});

EmailSettings.reopenClass({
  find: function() {
    return Discourse.ajax("/admin/email.json").then(function (settings) {
      return EmailSettings.create(settings);
    });
  }
});

export default EmailSettings;
