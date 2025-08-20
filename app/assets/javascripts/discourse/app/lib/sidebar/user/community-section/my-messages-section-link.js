import { service } from "@ember/service";
import BaseSectionLink from "discourse/lib/sidebar/base-community-section-link";
import { i18n } from "discourse-i18n";

export default class MyMessagesSectionLink extends BaseSectionLink {
  @service pmTopicTrackingState;

  get name() {
    return "my-messages";
  }

  get route() {
    return "userPrivateMessages.user";
  }

  get model() {
    return this.currentUser;
  }

  get title() {
    return i18n("sidebar.sections.community.links.my_messages.title");
  }

  get text() {
    return i18n(
      `sidebar.sections.community.links.${this.overriddenName
        .toLowerCase()
        .replace(" ", "_")}.content`,
      { defaultValue: this.overriddenName }
    );
  }

  get totalCount() {
    const newUserMsgs = this._lookupCount({ type: "new", inboxFilter: "user" });
    const unreadUserMsgs = this._lookupCount({
      type: "unread",
      inboxFilter: "user",
    });
    const groupMsgsCount = this.currentUser.groupsWithMessages?.reduce(
      (count, group) => {
        const newGroupMsgs = this._lookupCount({
          type: "new",
          inboxFilter: "group",
          groupName: group.name,
        });
        const unreadGroupMsgs = this._lookupCount({
          type: "unread",
          inboxFilter: "group",
          groupName: group.name,
        });

        return count + newGroupMsgs + unreadGroupMsgs;
      },
      0
    );

    return newUserMsgs + unreadUserMsgs + groupMsgsCount;
  }

  _lookupCount({ type, inboxFilter, groupName }) {
    const opts = { inboxFilter };
    return this.pmTopicTrackingState.lookupCount(
      type,
      groupName ? { ...opts, groupName } : opts
    );
  }

  get showCount() {
    return this.currentUser.sidebarShowCountOfNewItems;
  }

  get badgeText() {
    return this.showCount && this.totalCount;
  }

  get suffixCSSClass() {
    return "unread";
  }

  get suffixType() {
    return "icon";
  }

  get suffixValue() {
    if (!this.showCount && this.totalCount > 0) {
      return "circle";
    }
  }

  get shouldDisplay() {
    return this.currentUser?.can_send_private_messages;
  }

  get currentWhen() {
    return "userPrivateMessages";
  }
}
