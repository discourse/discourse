(function() {

  /**
    This controller supports the interface for reviewing email logs.

    @class AdminEmailLogsController    
    @extends Ember.ArrayController
    @namespace Discourse
    @module Discourse
  **/ 
  window.Discourse.AdminEmailLogsController = Ember.ArrayController.extend(Discourse.Presence, {
    
    /**
      Is the "send test email" button disabled?

      @property sendTestEmailDisabled
    **/    
    sendTestEmailDisabled: (function() {
      return this.blank('testEmailAddress');
    }).property('testEmailAddress'),

    /**
      Sends a test email to the currently entered email address

      @method sendTestEmail
    **/
    sendTestEmail: function() {
      var _this = this;
      _this.set('sentTestEmail', false);
      jQuery.ajax({
        url: '/admin/email_logs/test',
        type: 'POST',
        data: { email_address: this.get('testEmailAddress') },
        success: function() {
          return _this.set('sentTestEmail', true);
        }
      });
      return false;
    }
    
  });

}).call(this);
