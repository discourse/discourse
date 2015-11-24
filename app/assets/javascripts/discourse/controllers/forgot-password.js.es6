import ModalFunctionality from 'discourse/mixins/modal-functionality';

export default Ember.Controller.extend(ModalFunctionality, {

  // You need a value in the field to submit it.
  submitDisabled: function() {
    return Ember.isEmpty(this.get('accountEmailOrUsername')) || this.get('disabled');
  }.property('accountEmailOrUsername', 'disabled'),

  actions: {
    submit: function() {
      var self = this;

      if (this.get('submitDisabled')) return false;

      this.set('disabled', true);

      var success = function(data) {
        // don't tell people what happened, this keeps it more secure (ensure same on server)
        var escaped = Discourse.Utilities.escapeExpression(self.get('accountEmailOrUsername'));
        var isEmail = self.get('accountEmailOrUsername').match(/@/);

        var key = 'forgot_password.complete_' + (isEmail ? 'email' : 'username');
        var extraClass;

        if (data.user_found === true) {
          key += '_found';
        }

        if (data.user_found === false) {
          key += '_not_found';
          extraClass = 'error';
        }

        self.flash(I18n.t(key, {email: escaped, username: escaped}), extraClass);
      };

      var fail = function(e) {
        self.flash(e.responseJSON.errors[0], 'error');
      };

      Discourse.ajax('/session/forgot_password', {
        data: { login: this.get('accountEmailOrUsername') },
        type: 'POST'
      }).then(success, fail).finally(function(){
        setTimeout(function(){
          self.set('disabled',false);
        }, 1000);
      });

      return false;
    }
  }

});
