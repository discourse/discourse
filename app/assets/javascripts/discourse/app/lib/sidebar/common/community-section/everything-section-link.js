import I18n from "I18n";

import { tracked } from "@glimmer/tracking";
import BaseSectionLink from "discourse/lib/sidebar/base-community-section-link";
import { UNREAD_LIST_DESTINATION } from "discourse/controllers/preferences/sidebar";

export default class EverythingSectionLink extends BaseSectionLink {
  @tracked totalUnread = 0;
  @tracked totalNew = 0;

  constructor() {
    super(...arguments);
    this.#refreshCounts();
  }

  onTopicTrackingStateChange() {
    this.#refreshCounts();
  }

  #refreshCounts() {
    if (!this.currentUser) {
      return;
    }

    this.totalUnread = this.topicTrackingState.countUnread();

    if (this.totalUnread === 0) {
      this.totalNew = this.topicTrackingState.countNew();
    }
  }

  get name() {
    return "everything";
  }

  get query() {
    return { f: undefined };
  }

  get title() {
    return I18n.t("sidebar.sections.community.links.everything.title");
  }

  get text() {
    return I18n.t("sidebar.sections.community.links.everything.content");
  }

  get currentWhen() {
    return "discovery.latest discovery.new discovery.unread discovery.top";
  }

  get badgeText() {
    if (this.totalUnread > 0) {
      return I18n.t("sidebar.unread_count", {
        count: this.totalUnread,
      });
    } else if (this.totalNew > 0) {
      return I18n.t("sidebar.new_count", {
        count: this.totalNew,
      });
    } else {
      return;
    }
  }

  get route() {
    if (this.currentUser?.sidebarListDestination === UNREAD_LIST_DESTINATION) {
      if (this.totalUnread > 0) {
        return "discovery.unread";
      }
      if (this.totalNew > 0) {
        return "discovery.new";
      }
    }
    return "discovery.latest";
  }

  get prefixValue() {
    return "layer-group";
  }
}
