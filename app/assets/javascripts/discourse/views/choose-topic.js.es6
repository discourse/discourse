import debounce from 'discourse/lib/debounce';
import { searchForTerm } from 'discourse/lib/search';

export default Ember.View.extend({
  templateName: 'choose_topic',

  topicTitleChanged: function() {
    this.setProperties({
      loading: true,
      noResults: true,
      selectedTopicId: null,
    });
    this.search(this.get('topicTitle'));
  }.observes('topicTitle'),

  topicsChanged: function() {
    const topics = this.get('topics');
    if (topics) {
      this.set('noResults', topics.length === 0);
    }
    this.set('loading', false);
  }.observes('topics'),

  search: debounce(function(title) {
    const self = this,
          currentTopicId = this.get("currentTopicId");

    if (Em.isEmpty(title)) {
      self.setProperties({ topics: null, loading: false });
      return;
    }

    searchForTerm(title, { typeFilter: 'topic', searchForId: true }).then(function (results) {
      if (results && results.posts && results.posts.length > 0) {
        self.set('topics', results.posts.mapBy('topic').filter(t => t.get("id") !== currentTopicId));
      } else {
        self.setProperties({ topics: null, loading: false });
      }
    });
  }, 300),

  actions: {
    chooseTopic: function (topic) {
      const topicId = Em.get(topic, 'id');
      this.set('selectedTopicId', topicId);

      Em.run.next(function () {
        $('#choose-topic-' + topicId).prop('checked', 'true');
      });

      return false;
    }
  }

});
