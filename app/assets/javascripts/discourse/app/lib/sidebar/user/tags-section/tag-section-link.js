import { tracked } from "@glimmer/tracking";
import { bind } from "discourse/lib/decorators";
import BaseTagSectionLink from "discourse/lib/sidebar/user/tags-section/base-tag-section-link";
import { i18n } from "discourse-i18n";

export default class TagSectionLink extends BaseTagSectionLink {
  @tracked totalUnread = 0;
  @tracked totalNew = 0;

  constructor({ topicTrackingState }) {
    super(...arguments);
    this.topicTrackingState = topicTrackingState;
    this.refreshCounts();
  }

  @bind
  refreshCounts() {
    this.totalUnread = this.topicTrackingState.countUnread({
      tagId: this.tagName,
    });

    if (this.totalUnread === 0 || this.#newNewViewEnabled) {
      this.totalNew = this.topicTrackingState.countNew({
        tagId: this.tagName,
      });
    }
  }

  get showCount() {
    return this.currentUser?.sidebarShowCountOfNewItems;
  }

  get models() {
    return [this.tagName];
  }

  get route() {
    if (this.currentUser?.sidebarLinkToFilteredList) {
      if (this.#newNewViewEnabled && this.#unreadAndNewCount > 0) {
        return "tag.showNew";
      } else if (this.totalUnread > 0) {
        return "tag.showUnread";
      } else if (this.totalNew > 0) {
        return "tag.showNew";
      }
    }
    return "tag.show";
  }

  get currentWhen() {
    return "tag.show tag.showNew tag.showUnread tag.showTop";
  }

  get badgeText() {
    if (!this.showCount) {
      return;
    }

    if (this.#newNewViewEnabled && this.#unreadAndNewCount > 0) {
      return this.#unreadAndNewCount.toString();
    } else if (this.totalUnread > 0) {
      return i18n("sidebar.unread_count", {
        count: this.totalUnread,
      });
    } else if (this.totalNew > 0) {
      return i18n("sidebar.new_count", {
        count: this.totalNew,
      });
    }
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
