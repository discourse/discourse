/**
  A data model representing action types (flags, likes) against a Post

  @class PostActionType
  @extends Discourse.Model
  @namespace Discourse
  @module Discourse
**/
Discourse.PostActionType = Discourse.Model.extend({
});

Discourse.BoundPostActionType = Discourse.PostActionType.extend({
  customPlaceholder: function(){
    return Em.String.i18n("flagging.custom_placeholder_" + this.get('name_key'));
  }.property('name_key'), 

  formattedName: function(){
    return this.get('name').replace("{{username}}", this.get('post.username'));
  }.property('name'),

  messageChanged: function() {
    var len, message, minLen, _ref;
    minLen = 10;
    len = ((_ref = this.get('message')) ? _ref.length : void 0) || 0;
    this.set("customMessageLengthClasses", "too-short custom-message-length");
    if (len === 0) {
      message = Em.String.i18n("flagging.custom_message.at_least", { n: minLen });
    } else if (len < minLen) {
      message = Em.String.i18n("flagging.custom_message.more", { n: minLen - len });
    } else {
      message = Em.String.i18n("flagging.custom_message.left", { n: 500 - len });
      this.set("customMessageLengthClasses", "ok custom-message-length");
    }
    this.set("customMessageLength", message);
  }.observes("message")
});
