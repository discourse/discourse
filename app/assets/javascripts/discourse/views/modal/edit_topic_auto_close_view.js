/**
  This view handles a modal to set, edit, and remove a topic's auto-close time.

  @class EditTopicAutoCloseView
  @extends Discourse.ModalBodyView
  @namespace Discourse
  @module Discourse
**/
Discourse.EditTopicAutoCloseView = Discourse.ModalBodyView.extend({
  templateName: 'modal/auto_close',
  title: Em.String.i18n('topic.auto_close_title')
});