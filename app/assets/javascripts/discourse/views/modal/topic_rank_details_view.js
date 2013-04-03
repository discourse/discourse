/**
  A modal view for displaying the ranking details of a topic

  @class TopicRankDetailsView
  @extends Discourse.ModalBodyView
  @namespace Discourse
  @module Discourse
**/
Discourse.TopicRankDetailsView = Discourse.ModalBodyView.extend({
  templateName: 'modal/topic_rank_details',
  title: Em.String.i18n('rank_details.title')

});
