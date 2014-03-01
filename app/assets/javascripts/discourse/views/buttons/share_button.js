/**
  A button for sharing a link to a topic

  @class ShareButton
  @extends Discourse.ButtonView
  @namespace Discourse
  @module Discourse
**/
Discourse.ShareButton = Discourse.ButtonView.extend({
  classNames: ['share'],
  textKey: 'topic.share.title',
  helpKey: 'topic.share.help',
  'data-share-url': Em.computed.alias('topic.shareUrl'),
  topic: Em.computed.alias('controller.model'),

  renderIcon: function(buffer) {
    buffer.push("<i class='fa fa-link'></i>");
  }
});

