import { alias, and, or } from "@ember/object/computed";
import { computed } from "@ember/object";
import Component from "@ember/component";
import discourseComputed from "discourse-common/utils/decorators";
import { getTopicFooterButtons } from "discourse/lib/register-topic-footer-button";
import { getTopicFooterDropdowns } from "discourse/lib/register-topic-footer-dropdown";

export default Component.extend({
  elementId: "topic-footer-buttons",

  attributeBindings: ["role"],

  role: "region",

  // Allow us to extend it
  layoutName: "components/topic-footer-buttons",

  @discourseComputed("topic.isPrivateMessage")
  canArchive(isPM) {
    return this.siteSettings.enable_personal_messages && isPM;
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
    return !isPM || this.siteSettings.enable_personal_messages;
  },

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
});
