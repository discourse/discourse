/**
  A button for inviting users to reply to a topic

  @class InviteReplyButton
  @extends Discourse.ButtonView
  @namespace Discourse
  @module Discourse
**/
Discourse.InviteReplyButton = Discourse.ButtonView.extend({
  textKey: 'topic.invite_reply.title',
  helpKey: 'topic.invite_reply.help',
  attributeBindings: ['disabled'],
  disabled: Em.computed.or('controller.archived', 'controller.closed', 'controller.deleted'),

  renderIcon: function(buffer) {
    buffer.push("<i class='icon icon-group'></i>");
  },

  click: function() {
    return this.get('controller').send('showInvite');
  }
});