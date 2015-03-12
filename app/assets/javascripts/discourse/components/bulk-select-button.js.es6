import showModal from 'discourse/lib/show-modal';

export default Ember.Component.extend({
  actions: {
    showBulkActions() {
      const controller = showModal('topicBulkActions', this.get('selected'));
      controller.set('refreshTarget', this.get('refreshTarget'));
    }
  }
});
