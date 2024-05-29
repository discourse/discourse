import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { array, fn, hash } from "@ember/helper";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import routeAction from "discourse/helpers/route-action";
import GroupMessageSectionLink from "discourse/lib/sidebar/user/messages-section/group-message-section-link";
import PersonalMessageSectionLink from "discourse/lib/sidebar/user/messages-section/personal-message-section-link";
import { bind } from "discourse-common/utils/decorators";
import { i18n } from "discourse-i18n";
import Section from "../section";
import SectionLink from "../section-link";

export const INBOX = "inbox";
export const UNREAD = "unread";
const SENT = "sent";
export const NEW = "new";
const ARCHIVE = "archive";

export const PERSONAL_MESSAGES_INBOX_FILTERS = [
  INBOX,
  NEW,
  UNREAD,
  SENT,
  ARCHIVE,
];

export const GROUP_MESSAGES_INBOX_FILTERS = [INBOX, NEW, UNREAD, ARCHIVE];

export default class SidebarUserMessagesSection extends Component {
  @service appEvents;
  @service pmTopicTrackingState;
  @service currentUser;
  @service router;

  _pmTopicTrackingStateKey = "messages-section";

  constructor() {
    super(...arguments);

    this.appEvents.on(
      "page:changed",
      this,
      this._refreshSectionLinksDisplayState
    );

    this.pmTopicTrackingState.onStateChange(
      this._pmTopicTrackingStateKey,
      this._refreshSectionLinkCounts
    );
  }

  willDestroy() {
    super.willDestroy(...arguments);

    this.appEvents.off(
      "page:changed",
      this,
      this._refreshSectionLinksDisplayState
    );

    this.pmTopicTrackingState.offStateChange(
      this._pmTopicTrackingStateKey,
      this._refreshSectionLinkCounts
    );
  }

  @bind
  _refreshSectionLinkCounts() {
    for (const sectionLink of this.allSectionLinks) {
      sectionLink.refreshCount();
    }
  }

  _refreshSectionLinksDisplayState() {
    const currentRouteName = this.router.currentRoute.name;
    const currentRouteParentName = this.router.currentRoute.parent.name;
    const currentRouteParentParams = this.router.currentRoute.parent.params;

    if (
      !currentRouteParentName.includes("userPrivateMessages") &&
      currentRouteParentName !== "topic"
    ) {
      for (const sectionLink of this.allSectionLinks) {
        sectionLink.collapse();
      }
    } else {
      const attrs = {
        currentRouteName,
        currentRouteParentParams,
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
          pmTopicTrackingState: this.pmTopicTrackingState,
        })
      );
    });

    return links;
  }

  @cached
  get groupMessagesSectionLinks() {
    const links = [];

    this.currentUser.groupsWithMessages
      .sort((a, b) => a.name.localeCompare(b.name))
      .forEach((group) => {
        GROUP_MESSAGES_INBOX_FILTERS.forEach((groupMessageLink) => {
          links.push(
            new GroupMessageSectionLink({
              group,
              type: groupMessageLink,
              currentUser: this.currentUser,
              pmTopicTrackingState: this.pmTopicTrackingState,
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

  <template>
    <Section
      @sectionName="messages"
      @headerActionIcon="plus"
      @headerActions={{array
        (hash
          action=(fn (routeAction "composePrivateMessage") null null)
          title=(i18n "sidebar.sections.messages.header_action_title")
        )
      }}
      @headerActionsIcon="plus"
      @headerLinkText={{i18n "sidebar.sections.messages.header_link_text"}}
      @collapsable={{@collapsable}}
    >
      {{#each
        this.personalMessagesSectionLinks
        as |personalMessageSectionLink|
      }}
        {{#if personalMessageSectionLink.shouldDisplay}}
          <SectionLink
            @linkName={{personalMessageSectionLink.name}}
            @linkClass={{personalMessageSectionLink.class}}
            @route={{personalMessageSectionLink.route}}
            @model={{personalMessageSectionLink.model}}
            @prefixType={{personalMessageSectionLink.prefixType}}
            @prefixValue={{personalMessageSectionLink.prefixValue}}
            @currentWhen={{personalMessageSectionLink.currentWhen}}
            @content={{personalMessageSectionLink.text}}
          />
        {{/if}}
      {{/each}}

      {{#each this.groupMessagesSectionLinks as |groupMessageSectionLink|}}
        {{#if groupMessageSectionLink.shouldDisplay}}
          <SectionLink
            @linkName={{groupMessageSectionLink.name}}
            @linkClass={{groupMessageSectionLink.class}}
            @route={{groupMessageSectionLink.route}}
            @prefixType={{groupMessageSectionLink.prefixType}}
            @prefixValue={{groupMessageSectionLink.prefixValue}}
            @models={{groupMessageSectionLink.models}}
            @currentWhen={{groupMessageSectionLink.currentWhen}}
            @content={{groupMessageSectionLink.text}}
          />
        {{/if}}
      {{/each}}
    </Section>
  </template>
}
