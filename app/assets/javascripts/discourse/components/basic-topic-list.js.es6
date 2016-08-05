export default Ember.Component.extend({
  loadingMore: Ember.computed.alias('topicList.loadingMore'),
  loading: Ember.computed.not('loaded'),

  loaded: function() {
    var topicList = this.get('topicList');
    if (topicList) {
      return topicList.get('loaded');
    } else {
      return true;
    }
  }.property('topicList.loaded'),

  _topicListChanged: function() {
    this._initFromTopicList(this.get('topicList'));
  }.observes('topicList.[]'),

  _initFromTopicList(topicList) {
    if (topicList !== null) {
      this.set('topics', topicList.get('topics'));
      this.rerender();
    }
  },

  init() {
    this._super();
    const topicList = this.get('topicList');
    if (topicList) {
      this._initFromTopicList(topicList);
    } else {
      // Without a topic list, we assume it's loaded always.
      this.set('loaded', true);
    }
  },

  click(e) {
    // Mobile basic-topic-list doesn't use the `topic-list-item` view so
    // the event for the topic entrance is never wired up.
    if (!this.site.mobileView) { return; }

    let target = $(e.target);

    if (target.hasClass('posts-map')) {
      const topicId = target.closest('tr').attr('data-topic-id');
      if (topicId) {
        if (target.prop('tagName') !== 'A') {
          target = target.find('a');
        }

        const topic = this.get('topics').findProperty('id', parseInt(topicId));
        this.sendAction('postsAction', {topic, position: target.offset()});
      }
      return false;
    }

  }

});
