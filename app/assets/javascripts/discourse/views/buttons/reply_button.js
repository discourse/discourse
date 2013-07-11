/**
  A button for replying to a topic

  @class ReplyButton
  @extends Discourse.ButtonView
  @namespace Discourse
  @module Discourse
**/
Discourse.ReplyButton = Discourse.ButtonView.extend({
  classNames: ['btn', 'btn-primary', 'create'],
  attributeBindings: ['disabled'],
  helpKey: 'topic.reply.help',
  disabled: Em.computed.not('controller.model.details.can_create_post'),

  text: function() {
    var archetypeCapitalized = this.get('controller.content.archetype').capitalize();
    var customTitle = this.get("parentView.replyButtonText" + archetypeCapitalized);
    if (customTitle) { return customTitle; }

    return I18n.t("topic.reply.title");
  }.property(),

  renderIcon: function(buffer) {
    buffer.push("<i class='icon icon-plus'></i>");
  },

  click: function() {
    this.get('controller').reply();
  }
});

