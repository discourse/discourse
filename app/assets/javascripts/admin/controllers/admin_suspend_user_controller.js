/**
  The modal for suspending a user.

  @class AdminSuspendUserController
  @extends Discourse.Controller
  @namespace Discourse
  @uses Discourse.ModalFunctionality
  @module Discourse
**/
Discourse.AdminSuspendUserController = Discourse.ObjectController.extend(Discourse.ModalFunctionality, {

  submitDisabled: function() {
    return (!this.get('reason') || this.get('reason').length < 1);
  }.property('reason'),

  actions: {
    suspend: function() {
      if (this.get('submitDisabled')) return;
      var duration = parseInt(this.get('duration'), 10);
      if (duration > 0) {
        var self = this;
        this.send('hideModal');
        this.get('model').suspend(duration, this.get('reason')).then(function() {
          window.location.reload();
        }, function(e) {
          var error = I18n.t('admin.user.suspend_failed', { error: "http: " + e.status + " - " + e.body });
          bootbox.alert(error, function() { self.send('showModal'); });
        });
      }
    }
  }

});
