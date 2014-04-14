/**
  This view contains the topic map as well as other relevant information underneath the
  first post.

  @class TopicMapContainerView
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/
Discourse.TopicMapContainerView = Discourse.ContainerView.extend({
  classNameBindings: ['hidden', ':topic-map'],
  shouldRerender: Discourse.View.renderIfChanged('topic.posts_count'),

  hidden: function() {
    if (!this.get('post.firstPost')) return true;

    var topic = this.get('topic');
    if (topic.get('archetype') === 'private_message') return false;
    if (topic.get('archetype') !== 'regular') return true;
    return topic.get('posts_count') < 2;
  }.property(),

  init: function() {
    this._super();
    if (this.get('hidden')) return;

    this.attachViewWithArgs({ topic: this.get('topic') }, Discourse.TopicMapComponent);
    this.trigger('appendMapInformation', this);
  },

  appendMapInformation: function(container) {
    var topic = this.get('topic');

    // If we have a summary capability
    if (topic.get('has_summary')) {
      container.attachViewWithArgs({ topic: topic }, Discourse.ToggleSummaryComponent);
    }

    // If we have a private message
    if (this.get('topic.isPrivateMessage')) {
      container.attachViewWithArgs({ topic: topic, showPrivateInviteAction: 'showPrivateInvite' }, Discourse.PrivateMessageMapComponent);
    }
  }
});

