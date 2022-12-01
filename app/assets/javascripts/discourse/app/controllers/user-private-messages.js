import Controller, { inject as controller } from "@ember/controller";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { alias, and, equal, readOnly } from "@ember/object/computed";
import discourseComputed from "discourse-common/utils/decorators";
import I18n from "I18n";

export const PERSONAL_INBOX = "__personal_inbox__";

export default Controller.extend({
  user: controller(),
  router: service(),

  viewingSelf: alias("user.viewingSelf"),
  isGroup: equal("currentParentRouteName", "userPrivateMessages.group"),
  isPersonal: equal("currentParentRouteName", "userPrivateMessages.user"),
  group: null,
  groupFilter: alias("group.name"),
  currentRouteName: readOnly("router.currentRouteName"),
  currentParentRouteName: readOnly("router.currentRoute.parent.name"),
  pmTaggingEnabled: alias("site.can_tag_pms"),
  tagId: null,

  showNewPM: and("user.viewingSelf", "currentUser.can_send_private_messages"),

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
