/**
  A modal view for handling moving of posts to an existing topic

  @class MergeTopicView
  @extends Discourse.ModalBodyView
  @namespace Discourse
  @module Discourse
**/
Discourse.MergeTopicView = Discourse.ModalBodyView.extend({
  templateName: 'modal/merge_topic',
  title: Em.String.i18n('topic.merge_topic.title')
});


