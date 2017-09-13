import ModalFunctionality from 'discourse/mixins/modal-functionality';
import computed from 'ember-addons/ember-computed-decorators';
import { popupAjaxError } from 'discourse/lib/ajax-error';

export default Ember.Controller.extend(ModalFunctionality, {
  suspendUntil: null,
  reason: null,
  message: null,
  loading: false,

  onShow() {
    this.setProperties({
      suspendUntil: null,
      reason: null,
      message: null,
      loading: false
    });
  },

  @computed('suspendUntil', 'reason', 'loading')
  submitDisabled(suspendUntil, reason, loading) {
    return (loading || Ember.isEmpty(suspendUntil) || !reason || reason.length < 1);
  },

  actions: {
    suspend() {
      if (this.get('submitDisabled')) { return; }

      this.set('loading', true);
      this.get('model').suspend({
        suspend_until: this.get('suspendUntil'),
        reason: this.get('reason'),
        message: this.get('message')
      }).then(() => {
        this.send('closeModal');
      }).catch(popupAjaxError).finally(() => this.set('loading', false));
    }
  }

});
