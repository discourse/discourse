export default Ember.Controller.extend({
  description: Ember.computed('model.reason', function() {
    const reason = this.get('model.reason');
    return reason ? I18n.t('queue_reason.' + reason + '.description') : I18n.t('queue.approval.description');
  })
});
