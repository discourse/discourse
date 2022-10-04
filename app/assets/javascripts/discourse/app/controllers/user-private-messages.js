import Controller, { inject as controller } from "@ember/controller";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { alias, and, equal, readOnly } from "@ember/object/computed";
import discourseComputed from "discourse-common/utils/decorators";
import { VIEW_NAME_WARNINGS } from "discourse/routes/user-private-messages-warnings";
import I18n from "I18n";

export const PERSONAL_INBOX = "__personal_inbox__";

export default Controller.extend({
  user: controller(),
  router: service(),

  pmView: false,
  viewingSelf: alias("user.viewingSelf"),
  isGroup: equal("pmView", "group"),
  isPersonal: equal("pmView", "user"),
  group: null,
  groupFilter: alias("group.name"),
  currentPath: alias("router._router.currentPath"),
  currentRouteName: readOnly("router.currentRouteName"),
  pmTaggingEnabled: alias("site.can_tag_pms"),
  tagId: null,

  showNewPM: and("user.viewingSelf", "currentUser.can_send_private_messages"),

  @discourseComputed("viewingSelf", "pmView", "currentUser.admin")
  showWarningsWarning(viewingSelf, pmView, isAdmin) {
    return pmView === VIEW_NAME_WARNINGS && !viewingSelf && !isAdmin;
  },

  @discourseComputed(
    "pmTopicTrackingState.newIncoming.[]",
    "pmTopicTrackingState.statesModificationCounter",
    "group"
  )
  newLinkText() {
    return this._linkText("new");
  },

  @discourseComputed(
    "pmTopicTrackingState.newIncoming.[]",
    "pmTopicTrackingState.statesModificationCounter",
    "group"
  )
  unreadLinkText() {
    return this._linkText("unread");
  },

  _linkText(type) {
    const count = this.pmTopicTrackingState?.lookupCount(type) || 0;

    if (count === 0) {
      return I18n.t(`user.messages.${type}`);
    } else {
      return I18n.t(`user.messages.${type}_with_count`, { count });
    }
  },

  @action
  changeGroupNotificationLevel(notificationLevel) {
    this.group.setNotification(notificationLevel, this.get("user.model.id"));
  },
});
