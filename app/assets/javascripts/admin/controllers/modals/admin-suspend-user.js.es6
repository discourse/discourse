import ModalFunctionality from 'discourse/mixins/modal-functionality';
import computed from 'ember-addons/ember-computed-decorators';
import { popupAjaxError } from 'discourse/lib/ajax-error';

export default Ember.Controller.extend(ModalFunctionality, {
  duration: null,
  reason: null,
  message: null,
  loading: false,

  onShow() {
    this.setProperties({
      duration: null,
      reason: null,
      message: null,
      loading: false
    });
  },

  @computed('reason', 'loading')
  submitDisabled(reason, loading) {
    return (loading || !reason || reason.length < 1);
  },

  actions: {
    suspend() {
      if (this.get('submitDisabled')) { return; }

      let duration = parseInt(this.get('duration'), 10);
      if (duration > 0) {
        this.set('loading', true);
        this.get('model').suspend({
          duration,
          reason: this.get('reason'),
          message: this.get('message')
        }).then(() => {
          this.send('closeModal');
        }).catch(popupAjaxError).finally(() => this.set('loading', false));
      }
    }
  }

});
