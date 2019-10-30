import { alias, or, and } from "@ember/object/computed";
import Component from "@ember/component";
import computed from "ember-addons/ember-computed-decorators";
import { getTopicFooterButtons } from "discourse/lib/register-topic-footer-button";

export default Component.extend({
  elementId: "topic-footer-buttons",

  // Allow us to extend it
  layoutName: "components/topic-footer-buttons",

  @computed("topic.isPrivateMessage")
  canArchive(isPM) {
    return this.siteSettings.enable_personal_messages && isPM;
  },

  buttons: getTopicFooterButtons(),

  @computed("buttons.[]")
  inlineButtons(buttons) {
    return buttons.filter(button => !button.dropdown);
  },

  // topic.assigned_to_user is for backward plugin support
  @computed("buttons.[]", "topic.assigned_to_user")
  dropdownButtons(buttons) {
    return buttons.filter(button => button.dropdown);
  },

  @computed("topic.isPrivateMessage")
  showNotificationsButton(isPM) {
    return !isPM || this.siteSettings.enable_personal_messages;
  },

  canInviteTo: alias("topic.details.can_invite_to"),

  canDefer: alias("currentUser.enable_defer"),

  inviteDisabled: or(
    "topic.archived",
    "topic.closed",
    "topic.deleted"
  ),

  @computed
  showAdminButton() {
    return (
      !this.site.mobileView &&
      this.currentUser &&
      this.currentUser.get("canManageTopic")
    );
  },

  showEditOnFooter: and(
    "topic.isPrivateMessage",
    "site.can_tag_pms"
  ),

  @computed("topic.message_archived")
  archiveIcon: archived => (archived ? "envelope" : "folder"),

  @computed("topic.message_archived")
  archiveTitle: archived =>
    archived ? "topic.move_to_inbox.help" : "topic.archive_message.help",

  @computed("topic.message_archived")
  archiveLabel: archived =>
    archived ? "topic.move_to_inbox.title" : "topic.archive_message.title"
});
