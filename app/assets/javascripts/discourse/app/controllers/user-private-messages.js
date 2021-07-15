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
  currentPath: alias("router._router.currentPath"),
  pmTaggingEnabled: alias("site.can_tag_pms"),
  tagId: null,

  showNewPM: and("user.viewingSelf", "currentUser.can_send_private_messages"),

  @discourseComputed("viewingSelf", "pmView", "currentUser.admin")
  showWarningsWarning(viewingSelf, pmView, isAdmin) {
    return pmView === VIEW_NAME_WARNINGS && !viewingSelf && !isAdmin;
  },

  @action
  changeGroupNotificationLevel(notificationLevel) {
    this.group.setNotification(notificationLevel, this.get("user.model.id"));
  },
});
