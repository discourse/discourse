import I18n from "I18n";

import { tracked } from "@glimmer/tracking";
import BaseSectionLink from "discourse/lib/sidebar/base-community-section-link";
import { isTrackedTopic } from "discourse/lib/topic-list-tracked-filter";
import { UNREAD_LIST_DESTINATION } from "discourse/controllers/preferences/sidebar";

export default class TrackedSectionLink extends BaseSectionLink {
  @tracked totalUnread = 0;
  @tracked totalNew = 0;
  @tracked hideCount =
    this.currentUser?.sidebarListDestination !== UNREAD_LIST_DESTINATION;

  constructor() {
    super(...arguments);
    this.#refreshCounts();
  }

  onTopicTrackingStateChange() {
    this.#refreshCounts();
  }

  #refreshCounts() {
    this.totalUnread = this.topicTrackingState.countUnread({
      customFilterFn: isTrackedTopic,
    });

    if (this.totalUnread === 0) {
      this.totalNew = this.topicTrackingState.countNew({
        customFilterFn: isTrackedTopic,
      });
    }
  }

  get name() {
    return "tracked";
  }

  get query() {
    return { f: "tracked" };
  }

  get title() {
    return I18n.t("sidebar.sections.community.links.tracked.title");
  }

  get text() {
    return I18n.t("sidebar.sections.community.links.tracked.content");
  }

  get currentWhen() {
    return "discovery.latest discovery.new discovery.unread discovery.top";
  }

  get badgeText() {
    if (this.hideCount) {
      return;
    }
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
    return "bell";
  }

  get suffixCSSClass() {
    return "unread";
  }

  get suffixType() {
    return "icon";
  }

  get suffixValue() {
    if (this.hideCount && (this.totalUnread || this.totalNew)) {
      return "circle";
    }
  }
}
