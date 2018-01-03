import ModalFunctionality from 'discourse/mixins/modal-functionality';
import computed from 'ember-addons/ember-computed-decorators';
import { popupAjaxError } from 'discourse/lib/ajax-error';

export default Ember.Controller.extend(ModalFunctionality, {
  suspendUntil: null,
  reason: null,
  message: null,
  suspending: false,
  user: null,
  post: null,
  successCallback: null,

  onShow() {
    this.setProperties({
      suspendUntil: null,
      reason: null,
      message: null,
      suspending: false,
      loadingUser: true,
      post: null,
      successCallback: null,
    });
  },

  @computed('suspendUntil', 'reason', 'suspending')
  submitDisabled(suspendUntil, reason, suspending) {
    return (suspending || Ember.isEmpty(suspendUntil) || !reason || reason.length < 1);
  },

  actions: {
    suspend() {
      if (this.get('submitDisabled')) { return; }

      this.set('suspending', true);
      this.get('user').suspend({
        suspend_until: this.get('suspendUntil'),
        reason: this.get('reason'),
        message: this.get('message'),
        post_id: this.get('post.id')
      }).then(result => {
        this.send('closeModal');
        let callback = this.get('successCallback');
        if (callback) {
          callback(result);
        }
      }).catch(popupAjaxError).finally(() => this.set('suspending', false));
    }
  }

});
