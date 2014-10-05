/**
  Represents a pop up message displayed over the composer

  @class ComposerMessage
  @extends Ember.Object
  @namespace Discourse
  @module Discourse
**/
Discourse.ComposerMessage = Em.Object.extend({});

Discourse.ComposerMessage.reopenClass({
  /**
    Look for composer messages given the current composing settings.

    @method find
    @param {Discourse.Composer} composer The current composer
    @returns {Discourse.ComposerMessage} the composer message to display (or null)
  **/
  find: function(composer) {

    var data = { composerAction: composer.get('action') },
        topicId = composer.get('topic.id'),
        postId = composer.get('post.id');

    if (topicId) { data.topic_id = topicId; }
    if (postId)  { data.post_id = postId; }

    return Discourse.ajax('/composer-messages', { data: data }).then(function (messages) {
      return messages.map(function (message) {
        return Discourse.ComposerMessage.create(message);
      });
    });
  }

});
