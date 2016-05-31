import ContainerView from 'discourse/views/container';
import { on } from 'ember-addons/ember-computed-decorators';

export default ContainerView.extend({
  elementId: 'topic-footer-main-buttons',

  @on('init')
  createButtons() {
    const mobileView = this.site.mobileView;

    const topic = this.get('topic');

    if (!mobileView && this.currentUser.get('staff')) {
      const viewArgs = { topic, delegated: this.get('topicDelegated'), openUpwards: true };
      this.attachViewWithArgs(viewArgs, 'topic-admin-menu-button');
    }

    if (!topic.get('isPrivateMessage')) {
      if (mobileView) {
        this.attachViewWithArgs({ topic }, 'topic-footer-mobile-dropdown');
      } else {
        // We hide some controls from private messages
        this.attachViewClass('bookmark-button');
        this.attachViewClass('share-button');
        if (this.get('topic.details.can_flag_topic')) {
          this.attachViewClass('flag-topic-button');
        }
      }
    }

    if (!mobileView && this.get('topic.details.can_invite_to')) {
      this.attachViewClass('invite-reply-button');
    }

    if (topic.get('isPrivateMessage')) {
      this.attachViewClass('archive-button');
    }

    if (this.get('topic.details.can_create_post')) {
      this.attachViewClass('reply-button');
    }

    this.trigger('additionalButtons', this);
  }
});
