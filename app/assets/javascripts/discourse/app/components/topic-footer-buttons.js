import Component from "@ember/component";
import { computed } from "@ember/object";
import { alias, or } from "@ember/object/computed";
import { getOwner } from "@ember/owner";
import { attributeBindings } from "@ember-decorators/component";
import { NotificationLevels } from "discourse/lib/notification-levels";
import { getTopicFooterButtons } from "discourse/lib/register-topic-footer-button";
import { getTopicFooterDropdowns } from "discourse/lib/register-topic-footer-dropdown";
import TopicBookmarkManager from "discourse/lib/topic-bookmark-manager";
import discourseComputed from "discourse-common/utils/decorators";

@attributeBindings("role")
export default class TopicFooterButtons extends Component {
  elementId = "topic-footer-buttons";
  role = "region";

  @getTopicFooterButtons() inlineButtons;
  @getTopicFooterDropdowns() inlineDropdowns;

  @alias("currentUser.can_send_private_messages") canSendPms;
  @alias("topic.details.can_invite_to") canInviteTo;
  @alias("currentUser.user_option.enable_defer") canDefer;
  @or("topic.archived", "topic.closed", "topic.deleted") inviteDisabled;

  @discourseComputed("canSendPms", "topic.isPrivateMessage")
  canArchive(canSendPms, isPM) {
    return canSendPms && isPM;
  }

  @computed("inlineButtons.[]", "inlineDropdowns.[]")
  get inlineActionables() {
    return this.inlineButtons
      .filterBy("dropdown", false)
      .filterBy("anonymousOnly", false)
      .concat(this.inlineDropdowns)
      .sortBy("priority")
      .reverse();
  }

  @computed("topic")
  get topicBookmarkManager() {
    return new TopicBookmarkManager(getOwner(this), this.topic);
  }

  // topic.assigned_to_user is for backward plugin support
  @discourseComputed("inlineButtons.[]", "topic.assigned_to_user")
  dropdownButtons(inlineButtons) {
    return inlineButtons.filter((button) => button.dropdown);
  }

  @discourseComputed("topic.isPrivateMessage")
  showNotificationsButton(isPM) {
    return !isPM || this.canSendPms;
  }

  @discourseComputed(
    "showNotificationsButton",
    "topic.details.notification_level"
  )
  showNotificationUserTip(showNotificationsButton, notificationLevel) {
    return (
      showNotificationsButton &&
      notificationLevel >= NotificationLevels.TRACKING
    );
  }

  @discourseComputed("topic.message_archived")
  archiveIcon(archived) {
    return archived ? "envelope" : "folder";
  }

  @discourseComputed("topic.message_archived")
  archiveTitle(archived) {
    return archived ? "topic.move_to_inbox.help" : "topic.archive_message.help";
  }

  @discourseComputed("topic.message_archived")
  archiveLabel(archived) {
    return archived
      ? "topic.move_to_inbox.title"
      : "topic.archive_message.title";
  }

  @discourseComputed("topic.isPrivateMessage")
  showBookmarkLabel(isPM) {
    return !isPM;
  }
}
