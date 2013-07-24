/**
  This view is used for rendering a basic list of topics.

  @class PaginatedTopicListView
  @extends Discourse.View
  @namespace Discourse
  @uses Discourse.LoadMore
  @module Discourse
**/
Discourse.PaginatedTopicListView = Discourse.BasicTopicListView.extend(Discourse.LoadMore, {
  topics: Em.computed.alias('controller.model.topics'),
  classNames: ['paginated-topics-list'],
  eyelineSelector: '.paginated-topics-list #topic-list tr',

  loadMore: function() {
    this.get('controller.model').loadMoreTopics();
  }

});

