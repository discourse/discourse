/**
  The modal for banning a user.

  @class AdminBanUserController
  @extends Discourse.Controller
  @namespace Discourse
  @uses Discourse.ModalFunctionality
  @module Discourse
**/
Discourse.AdminBanUserController = Discourse.ObjectController.extend(Discourse.ModalFunctionality, {

  actions: {
    ban: function() {
      var duration = parseInt(this.get('duration'), 10);
      if (duration > 0) {
        var self = this;
        this.send('hideModal');
        this.get('model').ban(duration, this.get('reason')).then(function() {
          window.location.reload();
        }, function(e) {
          var error = I18n.t('admin.user.ban_failed', { error: "http: " + e.status + " - " + e.body });
          bootbox.alert(error, function() { self.send('showModal'); });
        });
      }
    }
  }

});
