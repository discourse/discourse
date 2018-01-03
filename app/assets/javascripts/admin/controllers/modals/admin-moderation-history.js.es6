import ModalFunctionality from 'discourse/mixins/modal-functionality';

export default Ember.Controller.extend(ModalFunctionality, {
  loading: null,
  historyTarget: null,
  history: null,

  onShow() {
    this.set('loading', true);
    this.set('history', null);
  },

  loadHistory(target) {
    this.store.findAll('moderation-history', target).then(result => {
      this.set('history', result);
    }).finally(() => this.set('loading', false));
  }
});
