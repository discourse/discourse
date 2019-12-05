import discourseComputed from "discourse-common/utils/decorators";
import { alias, or, and } from "@ember/object/computed";
import { propertyEqual } from "discourse/lib/computed";
import Component from "@ember/component";
import { getTopicFooterButtons } from "discourse/lib/register-topic-footer-button";

export default Component.extend({
  elementId: "topic-footer-buttons",

  // Allow us to extend it
  layoutName: "components/topic-footer-buttons",

  topicFeaturedOnProfile: propertyEqual(
    "topic.id",
    "currentUser.featured_topic.id"
  ),

  @discourseComputed("topic.isPrivateMessage")
  canArchive(isPM) {
    return this.siteSettings.enable_personal_messages && isPM;
  },

  buttons: getTopicFooterButtons(),

  @discourseComputed("buttons.[]")
  inlineButtons(buttons) {
    return buttons.filter(button => !button.dropdown);
  },

  // topic.assigned_to_user is for backward plugin support
  @discourseComputed("buttons.[]", "topic.assigned_to_user")
  dropdownButtons(buttons) {
    return buttons.filter(button => button.dropdown);
  },

  @discourseComputed("topic.isPrivateMessage")
  showNotificationsButton(isPM) {
    return !isPM || this.siteSettings.enable_personal_messages;
  },

  canInviteTo: alias("topic.details.can_invite_to"),

  canDefer: alias("currentUser.enable_defer"),

  inviteDisabled: or("topic.archived", "topic.closed", "topic.deleted"),

  @discourseComputed
  showAdminButton() {
    return (
      !this.site.mobileView &&
      this.currentUser &&
      this.currentUser.get("canManageTopic")
    );
  },

  showEditOnFooter: and("topic.isPrivateMessage", "site.can_tag_pms"),

  @discourseComputed("topic.message_archived")
  archiveIcon: archived => (archived ? "envelope" : "folder"),

  @discourseComputed("topic.message_archived")
  archiveTitle: archived =>
    archived ? "topic.move_to_inbox.help" : "topic.archive_message.help",

  @discourseComputed("topic.message_archived")
  archiveLabel: archived =>
    archived ? "topic.move_to_inbox.title" : "topic.archive_message.title",

  @discourseComputed(
    "topic.user_id",
    "topic.isPrivateMessage",
    "topic.category.read_restricted"
  )
  showToggleFeatureOnProfileButton(userId, isPm, restricted) {
    return (
      this.siteSettings.allow_featured_topic_on_user_profiles &&
      userId === this.currentUser.get("id") &&
      !restricted &&
      !isPm
    );
  }
});
