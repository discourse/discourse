import { ajax } from 'discourse/lib/ajax';
import { popupAjaxError } from 'discourse/lib/ajax-error';
import ModalFunctionality from 'discourse/mixins/modal-functionality';

export default Ember.Controller.extend(ModalFunctionality, {
  emailSent: false,

  onShow() {
    this.set("emailSent", false);
  },

  actions: {
    sendActivationEmail() {
      ajax('/users/action/send_activation_email', {
        data: { username: this.get('username') },
        type: 'POST'
      }).then(() => {
        this.set('emailSent', true);
      }).catch(popupAjaxError);
    }
  }

});
