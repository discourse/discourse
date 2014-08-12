import ModalFunctionality from 'discourse/mixins/modal-functionality';

import DiscourseController from 'discourse/controllers/controller';

export default DiscourseController.extend(ModalFunctionality, {
  emailSent: false,

  actions: {
    sendActivationEmail: function() {
      Discourse.ajax('/users/' + this.get('username') + '/send_activation_email', {type: 'POST'});
      this.set('emailSent', true);
    }
  }

});
