import TopicAdminMenuButton from 'discourse/views/topic-admin-menu-button';
import LoginReplyButton from 'discourse/views/login-reply-button';
import FlagTopicButton from 'discourse/views/flag-topic-button';
import BookmarkButton from 'discourse/views/bookmark-button';
import ShareButton from 'discourse/views/share-button';
import InviteReplyButton from 'discourse/views/invite-reply-button';
import ReplyButton from 'discourse/views/reply-button';
import PinnedButton from 'discourse/components/pinned-button';
import TopicNotificationsButton from 'discourse/components/topic-notifications-button';
import DiscourseContainerView from 'discourse/views/container';

export default DiscourseContainerView.extend({
  elementId: 'topic-footer-buttons',
  topicBinding: 'controller.content',

  init() {
    this._super();
    this.createButtons();
  },

  // Add the buttons below a topic
  createButtons() {
    const topic = this.get('topic');
    if (Discourse.User.current()) {
      const viewArgs = {topic};
      if (Discourse.User.currentProp("staff")) {
        this.attachViewClass(TopicAdminMenuButton);
      }
      if (!topic.get('isPrivateMessage')) {
        // We hide some controls from private messages
        if (this.get('topic.details.can_invite_to')) {
          this.attachViewClass(InviteReplyButton);
        }
        this.attachViewClass(BookmarkButton);
        this.attachViewClass(ShareButton);
        if (this.get('topic.details.can_flag_topic')) {
          this.attachViewClass(FlagTopicButton);
        }
      }
      if (this.get('topic.details.can_create_post')) {
        this.attachViewClass(ReplyButton);
      }
      this.attachViewWithArgs(viewArgs, PinnedButton);
      this.attachViewWithArgs(viewArgs, TopicNotificationsButton);

      this.trigger('additionalButtons', this);
    } else {
      // If not logged in give them a login control
      this.attachViewClass(LoginReplyButton);
    }
  }
});
