/**
  A data model representing action types (flags, likes) against a Post

  @class PostActionType
  @extends Discourse.Model
  @namespace Discourse
  @module Discourse
**/
Discourse.PostActionType = Discourse.Model.extend({});

Discourse.PostActionType.reopenClass({
  MIN_MESSAGE_LENGTH: 10,
  MAX_MESSAGE_LENGTH: 500
})
