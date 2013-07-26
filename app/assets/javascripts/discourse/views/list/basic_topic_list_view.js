/**
  This view is used for rendering a basic list of topics.

  @class BasicTopicListView
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/
Discourse.BasicTopicListView = Discourse.View.extend({
  templateName: 'list/basic_topic_list'
});
Discourse.View.registerHelper('basicTopicList', Discourse.BasicTopicListView);
