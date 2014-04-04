/**
  This controller supports email functionality.

  @class AdminEmailIndexController
  @extends Discourse.Controller
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminEmailIndexController = Discourse.Controller.extend({

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
      }).catch(function () {
        bootbox.alert(I18n.t('admin.email.test_error'));
      }).finally(function() {
        self.set('sendingEmail', false);
      });

    }
  }

});
