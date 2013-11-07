/**
  The modal for suspending a user.

  @class AdminSuspendUserController
  @extends Discourse.Controller
  @namespace Discourse
  @uses Discourse.ModalFunctionality
  @module Discourse
**/
Discourse.AdminSuspendUserController = Discourse.ObjectController.extend(Discourse.ModalFunctionality, {

  actions: {
    suspend: function() {
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
