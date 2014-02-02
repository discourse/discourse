/**
  Handles the view for the topic bulk actions modal

  @class TopicBulkActionsView
  @extends Discourse.ModalBodyView
  @namespace Discourse
  @module Discourse
**/
Discourse.TopicBulkActionsView = Discourse.ModalBodyView.extend({
  templateName: 'modal/topic_bulk_actions',
  title: I18n.t('topics.bulk.actions')
});
