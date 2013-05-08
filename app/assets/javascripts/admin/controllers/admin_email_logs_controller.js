/**
  This controller supports the interface for reviewing email logs.

  @class AdminEmailLogsController
  @extends Ember.ArrayController
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminEmailLogsController = Ember.ArrayController.extend(Discourse.Presence, {

  /**
    Is the "send test email" button disabled?

    @property sendTestEmailDisabled
  **/
  sendTestEmailDisabled: function() {
    return this.blank('testEmailAddress');
  }.property('testEmailAddress'),

  /**
    Sends a test email to the currently entered email address

    @method sendTestEmail
  **/
  sendTestEmail: function() {
    this.set('sentTestEmail', false);

    var adminEmailLogsController = this;
    Discourse.ajax("/admin/email_logs/test", {
      type: 'POST',
      data: { email_address: this.get('testEmailAddress') }
    }).then(function () {
      adminEmailLogsController.set('sentTestEmail', true);
    });

  }

});
