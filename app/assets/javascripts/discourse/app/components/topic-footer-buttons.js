import { alias, and, or } from "@ember/object/computed";
import { computed } from "@ember/object";
import Component from "@ember/component";
import discourseComputed from "discourse-common/utils/decorators";
import { getTopicFooterButtons } from "discourse/lib/register-topic-footer-button";
import { getTopicFooterDropdowns } from "discourse/lib/register-topic-footer-dropdown";
import { NotificationLevels } from "discourse/lib/notification-levels";
import I18n from "I18n";
import { duration } from "discourse/lib/formatter";

export default Component.extend({
  elementId: "topic-footer-buttons",

  attributeBindings: ["role"],

  role: "region",

  // Allow us to extend it
  layoutName: "components/topic-footer-buttons",

  @discourseComputed("canSendPms", "topic.isPrivateMessage")
  canArchive(canSendPms, isPM) {
    return canSendPms && isPM;
  },

  inlineButtons: getTopicFooterButtons(),
  inlineDropdowns: getTopicFooterDropdowns(),

  inlineActionables: computed(
    "inlineButtons.[]",
    "inlineDropdowns.[]",
    function () {
      return this.inlineButtons
        .filterBy("dropdown", false)
        .concat(this.inlineDropdowns)
        .sortBy("priority")
        .reverse();
    }
  ),

  // topic.assigned_to_user is for backward plugin support
  @discourseComputed("inlineButtons.[]", "topic.assigned_to_user")
  dropdownButtons(inlineButtons) {
    return inlineButtons.filter((button) => button.dropdown);
  },

  @discourseComputed("topic.isPrivateMessage")
  showNotificationsButton(isPM) {
    return !isPM || this.canSendPms;
  },

  canSendPms: alias("currentUser.can_send_private_messages"),

  canInviteTo: alias("topic.details.can_invite_to"),

  canDefer: alias("currentUser.enable_defer"),

  inviteDisabled: or("topic.archived", "topic.closed", "topic.deleted"),

  showEditOnFooter: and("topic.isPrivateMessage", "site.can_tag_pms"),

  @discourseComputed("topic.message_archived")
  archiveIcon: (archived) => (archived ? "envelope" : "folder"),

  @discourseComputed("topic.message_archived")
  archiveTitle: (archived) =>
    archived ? "topic.move_to_inbox.help" : "topic.archive_message.help",

  @discourseComputed("topic.message_archived")
  archiveLabel: (archived) =>
    archived ? "topic.move_to_inbox.title" : "topic.archive_message.title",

  @discourseComputed(
    "currentUser.auto_track_topics_after_msecs",
    "topic.details.notification_level"
  )
  onboardingPopupContent(autoTrackDuration, notificationLevel) {
    if (
      autoTrackDuration > 0 &&
      notificationLevel >= NotificationLevels.TRACKING
    ) {
      return I18n.t("popup.topic_notification_levels.content", {
        duration: duration(autoTrackDuration / 1000, { format: "medium" }),
      });
    }
  },
});
