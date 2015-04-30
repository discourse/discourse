export default Ember.Component.extend({
  layoutName: 'components/toggle-deleted',
  tagName: 'section',
  classNames: ['information'],
  postStream: Em.computed.alias('topic.postStream'),

  actions: {
    toggleDeleted: function() {
      this.get('postStream').toggleDeleted();
    }
  }
});
