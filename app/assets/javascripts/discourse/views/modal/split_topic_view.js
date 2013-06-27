/**
  A modal view for handling moving of posts to a new topic

  @class SplitTopicView
  @extends Discourse.ModalBodyView
  @namespace Discourse
  @module Discourse
**/
Discourse.SplitTopicView = Discourse.ModalBodyView.extend(Discourse.SelectedPostsCount, {
  templateName: 'modal/split_topic',
  title: Em.String.i18n('topic.split_topic.title')
});


