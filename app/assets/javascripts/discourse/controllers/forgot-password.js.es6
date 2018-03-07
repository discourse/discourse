import { ajax } from 'discourse/lib/ajax';
import ModalFunctionality from 'discourse/mixins/modal-functionality';
import { escapeExpression } from 'discourse/lib/utilities';
import { extractError } from 'discourse/lib/ajax-error';
import computed from 'ember-addons/ember-computed-decorators';

export default Ember.Controller.extend(ModalFunctionality, {
  offerHelp: null,
  helpSeen: false,

  @computed('accountEmailOrUsername', 'disabled')
  submitDisabled(accountEmailOrUsername, disabled) {
    return Ember.isEmpty((accountEmailOrUsername || '').trim()) || disabled;
  },

  onShow() {
    if ($.cookie('email')) {
      this.set('accountEmailOrUsername', $.cookie('email'));
    }
  },

  actions: {
    ok() {
      this.send('closeModal');
    },

    help() {
      this.setProperties({ offerHelp: I18n.t('forgot_password.help'), helpSeen: true });
    },

    resetPassword() {
      if (this.get('submitDisabled')) return false;
      this.set('disabled', true);

      this.clearFlash();

      ajax('/session/forgot_password', {
        data: { login: this.get('accountEmailOrUsername').trim() },
        type: 'POST'
      }).then(data => {
        const accountEmailOrUsername = escapeExpression(this.get("accountEmailOrUsername"));
        const isEmail = accountEmailOrUsername.match(/@/);
        let key = `forgot_password.complete_${isEmail ? 'email' : 'username'}`;
        if (data.user_found) {
          this.set('offerHelp', I18n.t(`${key}_found`, {
            email: accountEmailOrUsername,
            username: accountEmailOrUsername
          }));
        } else {
          this.flash(I18n.t(`${key}_not_found`, {
            email: accountEmailOrUsername,
            username: accountEmailOrUsername
          }), 'error');
        }
      }).catch(e => {
        this.flash(extractError(e), 'error');
      }).finally(() => {
        this.set('disabled', false);
      });

      return false;
    }
  },
});
