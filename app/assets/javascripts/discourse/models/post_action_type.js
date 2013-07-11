/**
  A data model representing action types (flags, likes) against a Post

  @class PostActionType
  @extends Discourse.Model
  @namespace Discourse
  @module Discourse
**/
Discourse.PostActionType = Discourse.Model.extend({
  notCustomFlag: Em.computed.not('is_custom_flag')
});

Discourse.PostActionType.reopenClass({
  MAX_MESSAGE_LENGTH: 500
});
