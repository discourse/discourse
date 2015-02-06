export default Ember.Component.extend({
  layoutName: 'components/toggle-summary',
  tagName: 'section',
  classNames: ['information'],
  postStream: Em.computed.alias('topic.postStream'),

  actions: {
    toggleSummary() {
      this.get('postStream').toggleSummary();
    }
  }
});
