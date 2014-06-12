/**
  This view presents the user with a widget to choose a topic.

  @class ChooseTopicView
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/
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
    Discourse.Search.forTerm(title, {typeFilter: 'topic'}).then(function (facets) {
      if (facets && facets[0] && facets[0].results) {
        self.set('topics', facets[0].results);
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
