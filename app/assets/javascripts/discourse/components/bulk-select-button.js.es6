import showModal from 'discourse/lib/show-modal';

export default Ember.Component.extend({
  actions: {
    showBulkActions() {
      const controller = showModal('topic-bulk-actions', { model: this.get('selected'), title: 'topics.bulk.actions' });
      controller.set('refreshClosure', () => this.sendAction());
    }
  }
});
