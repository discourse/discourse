import LoginReplyButton from 'discourse/views/login-reply-button';
import FlagTopicButton from 'discourse/views/flag-topic-button';
import StarButton from 'discourse/views/star-button';
import ShareButton from 'discourse/views/share-button';
import InviteReplyButton from 'discourse/views/invite-reply-button';
import ReplyButton from 'discourse/views/reply-button';
import PinnedButton from 'discourse/views/pinned-button';
import TopicNotificationsButton from 'discourse/views/topic-notifications-button';

export default Discourse.ContainerView.extend({
  elementId: 'topic-footer-buttons',
  topicBinding: 'controller.content',

  init: function() {
    this._super();
    this.createButtons();
  },

  // Add the buttons below a topic
  createButtons: function() {
    var topic = this.get('topic');
    if (Discourse.User.current()) {
      if (!topic.get('isPrivateMessage')) {
        // We hide some controls from private messages
        if (this.get('topic.details.can_invite_to')) {
          this.attachViewClass(InviteReplyButton);
        }
        this.attachViewClass(StarButton);
        this.attachViewClass(ShareButton);
        if (this.get('topic.details.can_flag_topic')) {
          this.attachViewClass(FlagTopicButton);
        }
      }
      if (this.get('topic.details.can_create_post')) {
        this.attachViewClass(ReplyButton);
      }
      this.attachViewClass(PinnedButton);
      this.attachViewClass(TopicNotificationsButton);

      this.trigger('additionalButtons', this);
    } else {
      // If not logged in give them a login control
      this.attachViewClass(LoginReplyButton);
    }
  }
});
