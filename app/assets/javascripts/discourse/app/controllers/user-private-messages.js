import Controller, { inject as controller } from "@ember/controller";
import { action } from "@ember/object";
import { alias, and, equal } from "@ember/object/computed";
import discourseComputed from "discourse-common/utils/decorators";
import { VIEW_NAME_WARNINGS } from "discourse/routes/user-private-messages-warnings";

export default Controller.extend({
  user: controller(),

  pmView: false,
  viewingSelf: alias("user.viewingSelf"),
  isGroup: equal("pmView", "groups"),
  group: null,
  groupFilter: alias("group.name"),
  userInbox: "__user_inbox__",
  tagsInbox: "__tags__",
  currentPath: alias("router._router.currentPath"),
  pmTaggingEnabled: alias("site.can_tag_pms"),
  tagId: null,

  showNewPM: and("user.viewingSelf", "currentUser.can_send_private_messages"),

  @discourseComputed("group.name")
  selectedInbox(groupName) {
    if (groupName) {
      return groupName;
    }
    return this.userInbox;
  },

  @discourseComputed("viewingSelf", "pmView", "currentUser.admin")
  showWarningsWarning(viewingSelf, pmView, isAdmin) {
    return pmView === VIEW_NAME_WARNINGS && !viewingSelf && !isAdmin;
  },

  @discourseComputed("model.groups")
  inboxes(groups) {
    const inboxes = [
      {
        id: this.userInbox,
        name: I18n.t("user.messages.inbox"),
        icon: "envelope",
      },
    ];

    groups.forEach((group) => {
      if (group.has_messages) {
        inboxes.push({ id: group.name, name: group.name, icon: "users" });
      }
    });

    return inboxes;
  },

  @action
  changeGroupNotificationLevel(notificationLevel) {
    this.group.setNotification(notificationLevel, this.get("user.model.id"));
  },

  @action
  updateInbox(inbox) {
    if (inbox === this.userInbox) {
      this.setProperties({ group: null, isGroup: false, pmView: false });
      this.transitionToRoute("userPrivateMessages.index");
    } else {
      this.transitionToRoute("userPrivateMessages.group", inbox);
    }
  },
});
