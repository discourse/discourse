import ContainerView from 'discourse/views/container';
import { default as property, observes, on } from 'ember-addons/ember-computed-decorators';

export default ContainerView.extend({
  classNameBindings: ['hidden', ':topic-map'],

  @observes('topic.posts_count')
  _postsChanged() {
    Ember.run.once(this, 'rerender');
  },

  @property
  hidden() {
    if (!this.get('post.firstPost')) return true;

    const topic = this.get('topic');
    if (topic.get('archetype') === 'private_message') return false;
    if (topic.get('archetype') !== 'regular') return true;
    return topic.get('posts_count') < 2;
  },

  @on('init')
  startAppending() {
    if (this.get('hidden')) return;

    this.attachViewWithArgs({ topic: this.get('topic') }, 'topic-map');
    this.trigger('appendMapInformation', this);
  },

  appendMapInformation(view) {
    const topic = this.get('topic');

    if (topic.get('has_summary')) {
      view.attachViewWithArgs({ topic, filterBinding: 'controller.filter' }, 'toggle-summary');
    }

    const currentUser = this.get('controller.currentUser');
    if (currentUser && currentUser.get('staff') && topic.get('has_deleted')) {
      view.attachViewWithArgs({ topic, filterBinding: 'controller.filter' }, 'topic-deleted');
    }

    if (this.get('topic.isPrivateMessage')) {
      view.attachViewWithArgs({ topic, showPrivateInviteAction: 'showInvite' }, 'private-message-map');
    }
  }
});
