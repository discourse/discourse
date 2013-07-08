/**
  Supports logic for flags in the modal

  @class FlagActionTypeController
  @extends Discourse.ObjectController
  @namespace Discourse
  @module Discourse
**/
Discourse.FlagActionTypeController = Discourse.ObjectController.extend({
  needs: ['flag'],

  message: Em.computed.alias('controllers.flag.message'),

  customPlaceholder: function(){
    return I18n.t("flagging.custom_placeholder_" + this.get('name_key'));
  }.property('name_key'),

  formattedName: function(){
    return this.get('name').replace("{{username}}", this.get('controllers.flag.username'));
  }.property('name'),

  selected: function() {
    return this.get('model') === this.get('controllers.flag.selected');
  }.property('controllers.flag.selected'),

  showMessageInput: Em.computed.and('is_custom_flag', 'selected'),
  showDescription: Em.computed.not('showMessageInput'),

  customMessageLengthClasses: function() {
    return (this.get('message.length') < Discourse.SiteSettings.min_private_message_post_length) ? "too-short" : "ok";
  }.property('message.length'),

  customMessageLength: function() {
    var len = this.get('message.length') || 0;
    var minLen = Discourse.SiteSettings.min_private_message_post_length;
    if (len === 0) {
      return I18n.t("flagging.custom_message.at_least", { n: minLen });
    } else if (len < minLen) {
      return I18n.t("flagging.custom_message.more", { n: minLen - len });
    } else {
      return I18n.t("flagging.custom_message.left", {
        n: Discourse.PostActionType.MAX_MESSAGE_LENGTH - len
      });
    }
  }.property('message.length')

});

