import { cached } from "@glimmer/tracking";

import { getOwner } from "discourse-common/lib/get-owner";
import GlimmerComponent from "discourse/components/glimmer";
import GroupMessageSectionLink from "discourse/lib/sidebar/messages-section/group-message-section-link";
import PersonalMessageSectionLink from "discourse/lib/sidebar/messages-section/personal-message-section-link";

export const INBOX = "inbox";
const UNREAD = "unread";
const SENT = "sent";
const NEW = "new";
const ARCHIVE = "archive";

export const PERSONAL_MESSAGES_INBOX_FILTERS = [
  INBOX,
  NEW,
  UNREAD,
  SENT,
  ARCHIVE,
];

export const GROUP_MESSAGES_INBOX_FILTERS = [INBOX, NEW, UNREAD, ARCHIVE];

export default class SidebarMessagesSection extends GlimmerComponent {
  constructor() {
    super(...arguments);

    this.appEvents.on(
      "page:changed",
      this,
      this._refreshSectionLinksDisplayState
    );
  }

  willDestroy() {
    this.appEvents.off(
      "page:changed",
      this,
      this._refreshSectionLinksDisplayState
    );
  }

  _refreshSectionLinksDisplayState({
    currentRouteName,
    currentRouteParentName,
    currentRouteParams,
  }) {
    if (
      currentRouteParentName !== "userPrivateMessages" &&
      currentRouteParentName !== "topic"
    ) {
      for (const sectionLink of this.allSectionLinks) {
        sectionLink.collapse();
      }
    } else {
      const attrs = {
        currentRouteName,
        currentRouteParams,
      };

      if (currentRouteParentName === "topic") {
        const topicController = getOwner(this).lookup("controller:topic");

        if (topicController.model.isPrivateMessage) {
          attrs.privateMessageTopic = topicController.model;
        }
      }

      for (const sectionLink of this.allSectionLinks) {
        sectionLink.pageChanged(attrs);
      }
    }
  }

  @cached
  get personalMessagesSectionLinks() {
    const links = [];

    PERSONAL_MESSAGES_INBOX_FILTERS.forEach((type) => {
      links.push(
        new PersonalMessageSectionLink({
          currentUser: this.currentUser,
          type,
        })
      );
    });

    return links;
  }

  @cached
  get groupMessagesSectionLinks() {
    const links = [];

    this.currentUser.groupsWithMessages.forEach((group) => {
      GROUP_MESSAGES_INBOX_FILTERS.forEach((groupMessageLink) => {
        links.push(
          new GroupMessageSectionLink({
            group,
            type: groupMessageLink,
            currentUser: this.currentUser,
          })
        );
      });
    });

    return links;
  }

  get allSectionLinks() {
    return [
      ...this.groupMessagesSectionLinks,
      ...this.personalMessagesSectionLinks,
    ];
  }
}
