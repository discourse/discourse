import computed from 'ember-addons/ember-computed-decorators';

export default Ember.Component.extend({
  tagName: 'li',
  classNames: ['category-link'],

  @computed('category.unreadTopics', 'category.newTopics')
  unreadTotal(unreadTopics, newTopics) {
    return parseInt(unreadTopics, 10) + parseInt(newTopics, 10);
  },

  showTopicCount: Ember.computed.not('currentUser')
});
