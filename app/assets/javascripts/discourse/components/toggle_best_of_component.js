Discourse.DiscourseToggleBestOfComponent = Ember.Component.extend({
  templateName: 'components/discourse-toggle-best-of',
  tagName: 'section',
  classNames: ['information'],
  postStream: Em.computed.alias('topic.postStream'),

  actions: {
    toggleBestOf: function() {
      this.get('postStream').toggleBestOf();
    }
  }
});
