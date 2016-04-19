import ContainerView from 'discourse/views/container';
import { on } from 'ember-addons/ember-computed-decorators';

export default ContainerView.extend({
  elementId: 'topic-footer-main-buttons',

  @on('init')
  createButtons() {
    const mobileView = this.site.mobileView;

    if (!mobileView && this.currentUser.get('staff')) {
      const viewArgs = {action: 'showTopicAdminMenu', title: 'topic_admin_menu', icon: 'wrench', position: 'absolute'};
      this.attachViewWithArgs(viewArgs, 'show-popup-button');
    }

    const topic = this.get('topic');
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

    if (this.get('topic.details.can_invite_to')) {
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
