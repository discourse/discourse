export default Ember.Controller.extend({

  /**
    Is the "send test email" button disabled?

    @property sendTestEmailDisabled
  **/
  sendTestEmailDisabled: Em.computed.empty('testEmailAddress'),

  /**
    Clears the 'sentTestEmail' property on successful send.

    @method testEmailAddressChanged
  **/
  testEmailAddressChanged: function() {
    this.set('sentTestEmail', false);
  }.observes('testEmailAddress'),

  actions: {
    /**
      Sends a test email to the currently entered email address

      @method sendTestEmail
    **/
    sendTestEmail: function() {
      this.setProperties({
        sendingEmail: true,
        sentTestEmail: false
      });

      var self = this;
      Discourse.ajax("/admin/email/test", {
        type: 'POST',
        data: { email_address: this.get('testEmailAddress') }
      }).then(function () {
        self.set('sentTestEmail', true);
      }, function(e) {
        if (e.responseJSON && e.responseJSON.errors) {
          bootbox.alert(I18n.t('admin.email.error', { server_error: e.responseJSON.errors[0] }));
        } else {
          bootbox.alert(I18n.t('admin.email.test_error'));
        }
      }).finally(function() {
        self.set('sendingEmail', false);
      });

    }
  }

});
