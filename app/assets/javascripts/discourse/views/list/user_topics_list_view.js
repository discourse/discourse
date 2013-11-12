/**
  This view is used for rendering a basic list of topics on a user's page.

  @class UserTopicsListView
  @extends Discourse.View
  @namespace Discourse
  @uses Discourse.LoadMore
  @module Discourse
**/
Discourse.UserTopicsListView = Discourse.View.extend(Discourse.LoadMore, {
  classNames: ['paginated-topics-list'],
  eyelineSelector: '.paginated-topics-list #topic-list tr',
  templateName: 'list/user_topics_list'
});

