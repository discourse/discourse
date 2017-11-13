import ModalFunctionality from 'discourse/mixins/modal-functionality';
import computed from 'ember-addons/ember-computed-decorators';
import { popupAjaxError } from 'discourse/lib/ajax-error';

export default Ember.Controller.extend(ModalFunctionality, {
  silenceUntil: null,
  reason: null,
  message: null,
  silencing: false,
  user: null,
  post: null,
  successCallback: null,

  onShow() {
    this.setProperties({
      silenceUntil: null,
      reason: null,
      message: null,
      silencing: false,
      loadingUser: true,
      post: null,
      successCallback: null,
    });
  },

  @computed('silenceUntil', 'reason', 'silencing')
  submitDisabled(silenceUntil, reason, silencing) {
    return (silencing || Ember.isEmpty(silenceUntil) || !reason || reason.length < 1);
  },

  actions: {
    silence() {
      if (this.get('submitDisabled')) { return; }

      this.set('silencing', true);
      this.get('user').silence({
        silenced_till: this.get('silenceUntil'),
        reason: this.get('reason'),
        message: this.get('message'),
        post_id: this.get('post.id')
      }).then(result => {
        this.send('closeModal');
        let callback = this.get('successCallback');
        if (callback) {
          callback(result);
        }
      }).catch(popupAjaxError).finally(() => this.set('silencing', false));
    }
  }
});
