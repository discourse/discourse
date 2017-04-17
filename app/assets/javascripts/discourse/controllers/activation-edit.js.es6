import computed from 'ember-addons/ember-computed-decorators';
import ModalFunctionality from 'discourse/mixins/modal-functionality';
import { ajax } from 'discourse/lib/ajax';
import { extractError } from 'discourse/lib/ajax-error';
import { userPath } from 'discourse/lib/url';

export default Ember.Controller.extend(ModalFunctionality, {
  login: Ember.inject.controller(),

  currentEmail: null,
  newEmail: null,
  password: null,

  @computed('newEmail', 'currentEmail')
  submitDisabled(newEmail, currentEmail) {
    return newEmail === currentEmail;
  },

  actions: {
    changeEmail() {
      const login = this.get('login');

      ajax(userPath('update-activation-email'), {
        data: {
          username: login.get('loginName'),
          password: login.get('loginPassword'),
          email: this.get('newEmail')
        },
        type: 'PUT'
      }).then(() => {
        const modal = this.showModal('activation-resent', {title: 'log_in'});
        modal.set('currentEmail', this.get('newEmail'));
      }).catch(err => this.flash(extractError(err), 'error'));
    }
  }
});
