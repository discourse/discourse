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
    // slug+id format if available, otherwise fallback to name
    // gotta reconfirm if this is necessary if not maintaining both
    if (this.tag?.slug && this.tag?.id) {
      return [this.tag.slug, this.tag.id];
    }
    return [this.tagName];
  }

  get route() {
    const hasSlugAndId = this.tag?.slug && this.tag?.id;
    const routePrefix = hasSlugAndId ? "tag.show" : "tag.showLegacy";

    if (this.currentUser?.sidebarLinkToFilteredList) {
      if (this.#newNewViewEnabled && this.#unreadAndNewCount > 0) {
        return hasSlugAndId ? "tag.showNew" : "tag.showLegacyNew";
      } else if (this.totalUnread > 0) {
        return hasSlugAndId ? "tag.showUnread" : "tag.showLegacyUnread";
      } else if (this.totalNew > 0) {
        return hasSlugAndId ? "tag.showNew" : "tag.showLegacyNew";
      }
    }
    return routePrefix;
  }

  get currentWhen() {
    return "tag.show tag.showNew tag.showUnread tag.showTop tag.showHot tag.showLatest tag.showLegacy tag.showLegacyNew tag.showLegacyUnread tag.showLegacyTop tag.showLegacyHot tag.showLegacyLatest";
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
