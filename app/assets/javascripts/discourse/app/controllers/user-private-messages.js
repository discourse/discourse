import Controller, { inject as controller } from "@ember/controller";
import { action, computed } from "@ember/object";
import { inject as service } from "@ember/service";
import { alias, and, equal, readOnly } from "@ember/object/computed";
import { tracked } from "@glimmer/tracking";
import I18n from "I18n";

export const PERSONAL_INBOX = "__personal_inbox__";

export default class extends Controller {
  @service router;
  @controller user;

  @tracked group;
  @tracked tagId;

  @alias("group.name") groupFilter;
  @and("user.viewingSelf", "currentUser.can_send_private_messages") showNewPM;
  @equal("currentParentRouteName", "userPrivateMessages.group") isGroup;
  @equal("currentParentRouteName", "userPrivateMessages.user") isPersonal;
  @readOnly("user.viewingSelf") viewingSelf;
  @readOnly("router.currentRouteName") currentRouteName;
  @readOnly("router.currentRoute.parent.name") currentParentRouteName;
  @readOnly("site.can_tag_pms") pmTaggingEnabled;

  @computed(
    "pmTopicTrackingState.newIncoming.[]",
    "pmTopicTrackingState.statesModificationCounter",
    "group"
  )
  get newLinkText() {
    return this.#linkText("new");
  }

  @computed(
    "pmTopicTrackingState.newIncoming.[]",
    "pmTopicTrackingState.statesModificationCounter",
    "group"
  )
  get unreadLinkText() {
    return this.#linkText("unread");
  }

  #linkText(type) {
    const count = this.pmTopicTrackingState?.lookupCount(type) || 0;

    if (count === 0) {
      return I18n.t(`user.messages.${type}`);
    } else {
      return I18n.t(`user.messages.${type}_with_count`, { count });
    }
  }

  @action
  changeGroupNotificationLevel(notificationLevel) {
    this.group.setNotification(notificationLevel, this.get("user.model.id"));
  }
}
