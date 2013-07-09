/**
  A modal view for handling moving of posts to a new topic

  @class SplitTopicView
  @extends Discourse.ModalBodyView
  @namespace Discourse
  @module Discourse
**/
Discourse.SplitTopicView = Discourse.ModalBodyView.extend(Discourse.SelectedPostsCount, {
  templateName: 'modal/split_topic',
  title: I18n.t('topic.split_topic.title')
});


