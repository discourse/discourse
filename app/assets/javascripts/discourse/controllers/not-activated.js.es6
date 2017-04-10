import { ajax } from 'discourse/lib/ajax';
import { popupAjaxError } from 'discourse/lib/ajax-error';
import ModalFunctionality from 'discourse/mixins/modal-functionality';
import { userPath } from 'discourse/lib/url';

export default Ember.Controller.extend(ModalFunctionality, {
  actions: {
    sendActivationEmail() {
      ajax(userPath('action/send_activation_email'), {
        data: { username: this.get('username') },
        type: 'POST'
      }).then(() => {
        const modal = this.showModal('activation-resent', {title: 'log_in'});
        modal.set('currentEmail', this.get('currentEmail'));
      }).catch(popupAjaxError);
    },

    editActivationEmail() {
      const modal = this.showModal('activation-edit', {title: 'login.change_email'});

      const currentEmail = this.get('currentEmail');
      modal.set('currentEmail', currentEmail);
      modal.set('newEmail', currentEmail);
    }
  }
});
