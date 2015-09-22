import ContainerView from 'discourse/views/container';
import { on } from 'ember-addons/ember-computed-decorators';

export default ContainerView.extend({
  elementId: 'topic-footer-main-buttons',

  @on('init')
  createButtons() {
    if (this.currentUser.get('staff')) {
      const viewArgs = {action: 'showTopicAdminMenu', title: 'topic_admin_menu', icon: 'wrench', position: 'absolute'};
      this.attachViewWithArgs(viewArgs, 'show-popup-button');
    }

    const topic = this.get('topic');
    if (!topic.get('isPrivateMessage')) {
      // We hide some controls from private messages
      if (this.get('topic.details.can_invite_to')) {
        this.attachViewClass('invite-reply-button');
      }
      this.attachViewClass('bookmark-button');
      this.attachViewClass('share-button');
      if (this.get('topic.details.can_flag_topic')) {
        this.attachViewClass('flag-topic-button');
      }
    }
    if (this.get('topic.details.can_create_post')) {
      this.attachViewClass('reply-button');
    }
  }
});
