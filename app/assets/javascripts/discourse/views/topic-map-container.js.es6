import PrivateMessageMapComponent from 'discourse/components/private-message-map';
import TopicMapComponent from 'discourse/components/topic-map';
import ToggleSummaryComponent from 'discourse/components/toggle-summary';
import ToggleDeletedComponent from 'discourse/components/toggle-deleted';
import DiscourseContainerView from 'discourse/views/container';

export default DiscourseContainerView.extend({
  classNameBindings: ['hidden', ':topic-map'],

  _postsChanged: function() {
    Ember.run.once(this, 'rerender');
  }.observes('topic.posts_count'),

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

    if (Discourse.User.currentProp('staff')) {
      // If we have deleted post filtering
      if (topic.get('has_deleted')) {
        container.attachViewWithArgs({
          topic: topic,
          filterBinding: 'controller.filter'
        }, ToggleDeletedComponent);
      }
    }

    // If we have a private message
    if (this.get('topic.isPrivateMessage')) {
      container.attachViewWithArgs({ topic: topic, showPrivateInviteAction: 'showPrivateInvite' }, PrivateMessageMapComponent);
    }
  }
});

