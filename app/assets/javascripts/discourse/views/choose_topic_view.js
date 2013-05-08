/**
  This view presents the user with a widget to choose a topic.

  @class ChooseTopicView
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/
Discourse.ChooseTopicView = Discourse.View.extend({
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
    var chooseTopicView = this;
    Discourse.Search.forTerm(title, 'topic').then(function (facets) {
      if (facets && facets[0] && facets[0].results) {
        chooseTopicView.set('topics', facets[0].results);
      } else {
        chooseTopicView.set('topics', null);
        chooseTopicView.set('loading', false);
      }
    });
  }, 300),

  chooseTopic: function (topic) {
    var topicId = Em.get(topic, 'id');
    this.set('selectedTopicId', topicId);

    Em.run.next(function() {
      $('#choose-topic-' + topicId).prop('checked', 'true');
    });

    return false;
  }

});


