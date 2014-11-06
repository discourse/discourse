import searchForTerm from 'discourse/lib/search-for-term';

export default Discourse.View.extend({
  templateName: 'choose_topic',

  topicTitleChanged: function() {
    this.set('loading', true);
    this.set('noResults', true);
    this.set('selectedTopicId', null);
    this.search(this.get('topicTitle'));
  }.observes('topicTitle'),

  topicsChanged: function() {
    var topics = this.get('topics');
    if (topics) {
      this.set('noResults', topics.length === 0);
    }
    this.set('loading', false);
  }.observes('topics'),

  search: Discourse.debounce(function(title) {
    var self = this;
    if (Em.isEmpty(title)) {
      self.setProperties({ topics: null, loading: false });
      return;
    }
    searchForTerm(title, {typeFilter: 'topic', searchForId: true}).then(function (results) {
      if (results && results.posts && results.posts.length > 0) {
        self.set('topics', results.posts.mapBy('topic'));
      } else {
        self.setProperties({ topics: null, loading: false });
      }
    });
  }, 300),

  actions: {
    chooseTopic: function (topic) {
      var topicId = Em.get(topic, 'id');
      this.set('selectedTopicId', topicId);

      Em.run.next(function () {
        $('#choose-topic-' + topicId).prop('checked', 'true');
      });

      return false;
    }
  }

});
