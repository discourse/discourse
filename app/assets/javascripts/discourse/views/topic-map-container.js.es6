/**
  This view contains the topic map as well as other relevant information underneath the
  first post.

  @class TopicMapContainerView
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/
import PrivateMessageMapComponent from 'discourse/components/private-message-map';
import TopicMapComponent from 'discourse/components/topic-map';
import ToggleSummaryComponent from 'discourse/components/toggle-summary';

export default Discourse.ContainerView.extend({
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

    this.attachViewWithArgs({ topic: this.get('topic') }, TopicMapComponent);
    this.trigger('appendMapInformation', this);
  },

  appendMapInformation: function(container) {
    var topic = this.get('topic');

    // If we have a summary capability
    if (topic.get('has_summary')) {
      container.attachViewWithArgs({
        topic: topic,
        filterBinding: 'controller.filter'
      }, ToggleSummaryComponent);
    }

    // If we have a private message
    if (this.get('topic.isPrivateMessage')) {
      container.attachViewWithArgs({ topic: topic, showPrivateInviteAction: 'showPrivateInvite' }, PrivateMessageMapComponent);
    }
  }
});

