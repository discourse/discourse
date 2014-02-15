/**
  A button for flagging a topic

  @class FlagTopicButton
  @extends Discourse.ButtonView
  @namespace Discourse
  @module Discourse
**/
Discourse.FlagTopicButton = Discourse.ButtonView.extend({
  classNames: ['flag-topic'],
  textKey: 'topic.flag_topic.title',
  helpKey: 'topic.flag_topic.help',

  click: function() {
    this.get('controller').send('showFlagTopic', this.get('controller.content'));
  },

  renderIcon: function(buffer) {
    buffer.push("<i class='fa fa-flag'></i>");
  }
});

