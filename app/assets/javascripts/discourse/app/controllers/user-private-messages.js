import Controller, { inject as controller } from "@ember/controller";
import { action } from "@ember/object";
import { alias, and, equal } from "@ember/object/computed";
import discourseComputed from "discourse-common/utils/decorators";
import { VIEW_NAME_WARNINGS } from "discourse/routes/user-private-messages-warnings";
import { inject as service } from "@ember/service";
import DiscourseURL from "discourse/lib/url";

const personalInbox = "__personal_inbox__";
const allInbox = "__all_inbox__";

export default Controller.extend({
  queryParams: ["tag"],
  user: controller(),
  router: service(),

  pmView: false,
  viewingSelf: alias("user.viewingSelf"),
  isGroup: equal("pmView", "groups"),
  group: null,
  groupFilter: alias("group.name"),
  currentPath: alias("router._router.currentPath"),
  pmTaggingEnabled: alias("site.can_tag_pms"),
  tag: null,

  showNewPM: and("user.viewingSelf", "currentUser.can_send_private_messages"),

  @discourseComputed("pmView")
  isPersonalInbox(pmView) {
    return pmView && pmView.startsWith("personal");
  },

  @discourseComputed("isPersonalInbox", "group.name")
  isAllInbox(isPersonalInbox, groupName) {
    return !this.isPersonalInbox && !groupName;
  },

  @discourseComputed("isPersonalInbox", "group.name")
  selectedInbox(isPersonalInbox, groupName) {
    if (groupName) {
      return groupName;
    }

    return isPersonalInbox ? personalInbox : allInbox;
  },

  @discourseComputed("viewingSelf", "pmView", "currentUser.admin")
  showWarningsWarning(viewingSelf, pmView, isAdmin) {
    return pmView === VIEW_NAME_WARNINGS && !viewingSelf && !isAdmin;
  },

  @discourseComputed("tags")
  tagsContent(tags) {
    return tags.map((tag) => {
      return { id: tag.id, name: tag.text };
    });
  },

  @discourseComputed("model.groups", "tags")
  inboxes(groups) {
    const inboxes = [
      {
        id: allInbox,
        name: I18n.t("user.messages.all"),
      },
      {
        id: personalInbox,
        name: I18n.t("user.messages.personal"),
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
    const queryParams = {};

    if (this.tag) {
      queryParams.tag = this.tag;
    }

    if (inbox === allInbox) {
      this.setProperties({ group: null, isGroup: false, pmView: false });
      this.transitionToRoute("userPrivateMessages.index", { queryParams });
    } else if (inbox === personalInbox) {
      this.setProperties({ group: null, isGroup: false, pmView: false });
      this.transitionToRoute("userPrivateMessages.personal", { queryParams });
    } else {
      this.transitionToRoute("userPrivateMessages.group", inbox, {
        queryParams,
      });
    }
  },
});
