import ModalFunctionality from 'discourse/mixins/modal-functionality';

import DiscourseController from 'discourse/controllers/controller';

export default DiscourseController.extend(ModalFunctionality, {

  // You need a value in the field to submit it.
  submitDisabled: function() {
    return this.blank('accountEmailOrUsername') || this.get('disabled');
  }.property('accountEmailOrUsername', 'disabled'),

  actions: {
    submit: function() {
      var self = this;

      if (this.get('submitDisabled')) return false;

      this.set('disabled', true);

      var success = function() {
        // don't tell people what happened, this keeps it more secure (ensure same on server)
        var escaped = Handlebars.Utils.escapeExpression(self.get('accountEmailOrUsername'));
        if (self.get('accountEmailOrUsername').match(/@/)) {
          self.flash(I18n.t('forgot_password.complete_email', {email: escaped}));
        } else {
          self.flash(I18n.t('forgot_password.complete_username', {username: escaped}));
        }
      };

      var fail = function(e) {
        self.flash(e.responseJSON.errors[0], 'alert-error');
      };

      Discourse.ajax('/session/forgot_password', {
        data: { login: this.get('accountEmailOrUsername') },
        type: 'POST'
      }).then(success, fail).finally(function(){
        setTimeout(function(){
          self.set('disabled',false);
        }, 10*1000);
      });

      return false;
    }
  }

});
