import I18n from "I18n";

import { tracked } from "@glimmer/tracking";
import BaseSectionLink from "discourse/lib/sidebar/base-community-section-link";

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

    if (this.totalUnread === 0 || this.#newNewViewEnabled) {
      this.totalNew = this.topicTrackingState.countNew();
    }
  }

  get showCount() {
    return this.currentUser?.sidebarShowCountOfNewItems;
  }

  get name() {
    return "everything";
  }

  get query() {
    return { f: undefined };
  }

  get title() {
    return I18n.t("sidebar.sections.community.links.topics.title");
  }

  get text() {
    return I18n.t(
      `sidebar.sections.community.links.${this.overridenName.toLowerCase()}.content`,
      { defaultValue: this.overridenName }
    );
  }

  get currentWhen() {
    return "discovery.latest discovery.new discovery.unread discovery.top";
  }

  get badgeText() {
    if (!this.showCount) {
      return;
    }

    if (this.#newNewViewEnabled && this.#unreadAndNewCount > 0) {
      return this.#unreadAndNewCount.toString();
    } else if (this.totalUnread > 0) {
      return I18n.t("sidebar.unread_count", {
        count: this.totalUnread,
      });
    } else if (this.totalNew > 0) {
      return I18n.t("sidebar.new_count", {
        count: this.totalNew,
      });
    }
  }

  get route() {
    if (this.currentUser?.sidebarLinkToFilteredList) {
      if (this.#newNewViewEnabled && this.#unreadAndNewCount > 0) {
        return "discovery.new";
      } else if (this.totalUnread > 0) {
        return "discovery.unread";
      } else if (this.totalNew > 0) {
        return "discovery.new";
      }
    }
    return "discovery.latest";
  }

  get defaultPrefixValue() {
    return "layer-group";
  }

  get suffixCSSClass() {
    return "unread";
  }

  get suffixType() {
    return "icon";
  }

  get suffixValue() {
    if (!this.showCount && (this.totalUnread || this.totalNew)) {
      return "circle";
    }
  }

  get #unreadAndNewCount() {
    return this.totalUnread + this.totalNew;
  }

  get #newNewViewEnabled() {
    return !!this.currentUser?.new_new_view_enabled;
  }
}
