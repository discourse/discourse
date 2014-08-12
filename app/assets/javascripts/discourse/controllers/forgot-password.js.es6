import ModalFunctionality from 'discourse/mixins/modal-functionality';

import DiscourseController from 'discourse/controllers/controller';

export default DiscourseController.extend(ModalFunctionality, {

  // You need a value in the field to submit it.
  submitDisabled: function() {
    return this.blank('accountEmailOrUsername');
  }.property('accountEmailOrUsername'),

  actions: {
    submit: function() {
      if (!this.get('accountEmailOrUsername')) return false;

      Discourse.ajax("/session/forgot_password", {
        data: { login: this.get('accountEmailOrUsername') },
        type: 'POST'
      });

      // don't tell people what happened, this keeps it more secure (ensure same on server)
      var escaped = Handlebars.Utils.escapeExpression(this.get('accountEmailOrUsername'));
      if (this.get('accountEmailOrUsername').match(/@/)) {
        this.flash(I18n.t('forgot_password.complete_email', {email: escaped}));
      } else {
        this.flash(I18n.t('forgot_password.complete_username', {username: escaped}));
      }
      return false;
    }
  }

});
