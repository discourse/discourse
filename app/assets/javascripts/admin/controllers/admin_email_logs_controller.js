(function() {

  window.Discourse.AdminEmailLogsController = Ember.ArrayController.extend(Discourse.Presence, {
    sendTestEmailDisabled: (function() {
      return this.blank('testEmailAddress');
    }).property('testEmailAddress'),
    sendTestEmail: function() {
      var _this = this;
      this.set('sentTestEmail', false);
      jQuery.ajax({
        url: '/admin/email_logs/test',
        type: 'POST',
        data: {
          email_address: this.get('testEmailAddress')
        },
        success: function() {
          return _this.set('sentTestEmail', true);
        }
      });
      return false;
    }
  });

}).call(this);
