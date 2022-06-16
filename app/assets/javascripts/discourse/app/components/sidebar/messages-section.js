import { action } from "@ember/object";
import { cached } from "@glimmer/tracking";

import GlimmerComponent from "discourse/components/glimmer";
import Composer from "discourse/models/composer";
import { getOwner } from "discourse-common/lib/get-owner";
import GroupMessageSectionLink from "discourse/lib/sidebar/messages-section/group-message-section-link";
import PersonalMessageSectionLink from "discourse/lib/sidebar/messages-section/personal-message-section-link";

export const INBOX = "inbox";
const UNREAD = "unread";
const SENT = "sent";
const NEW = "new";
const ARCHIVE = "archive";

export const PERSONAL_MESSAGES_INBOXES = [INBOX, UNREAD, NEW, SENT, ARCHIVE];
export const GROUP_MESSAGES_INBOXES = [INBOX, UNREAD, NEW, ARCHIVE];

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
    const sectionLinks = [
      ...this.personalMessagesSectionLinks,
      ...this.groupMessagesSectionLinks,
    ];

    if (currentRouteParentName !== "userPrivateMessages") {
      sectionLinks.forEach((sectionLink) => {
        sectionLink.collapse();
      });
    } else {
      sectionLinks.forEach((sectionLink) => {
        sectionLink.pageChanged(currentRouteName, currentRouteParams);
      });
    }
  }

  @cached
  get personalMessagesSectionLinks() {
    const links = [];

    PERSONAL_MESSAGES_INBOXES.forEach((type) => {
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
      GROUP_MESSAGES_INBOXES.forEach((groupMessageLink) => {
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

  @action
  composePersonalMessage() {
    const composerArgs = {
      action: Composer.PRIVATE_MESSAGE,
      draftKey: Composer.NEW_TOPIC_KEY,
    };

    getOwner(this).lookup("controller:composer").open(composerArgs);
  }
}
