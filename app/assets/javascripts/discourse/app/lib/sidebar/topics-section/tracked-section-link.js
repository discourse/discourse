import I18n from "I18n";

import { tracked } from "@glimmer/tracking";
import BaseSectionLink from "discourse/lib/sidebar/topics-section/base-section-link";
export default class TrackedSectionLink extends BaseSectionLink {
  @tracked totalUnread = 0;
  @tracked totalNew = 0;

  constructor() {
    super(...arguments);

    this.topicTrackingState.onStateChange(this._refreshCounts.bind(this));
    this._refreshCounts();
  }

  _refreshCounts() {
    this.totalUnread = this.topicTrackingState.countUnread(
      null,
      null,
      false,
      this._isTracking.bind(this)
    );

    if (this.totalUnread === 0) {
      this.totalNew = this.topicTrackingState.countNew(
        null,
        null,
        false,
        this._isTracking.bind(this)
      );
    }
  }

  _isTracking(topic) {
    let i = this.trackedCategories.length - 1;

    while (i >= 0) {
      const category = this.trackedCategories[i];

      if (
        category &&
        (category.id === topic.category_id ||
          (category.subcategories &&
            category.subcategories.some((c) => c.id === topic.category_id)))
      ) {
        return true;
      }

      i -= 1;
    }

    return false;
  }

  get name() {
    return "tracked";
  }

  get query() {
    return { f: "tracked" };
  }

  get title() {
    return I18n.t("sidebar.sections.topics.links.tracked.title");
  }

  get text() {
    return I18n.t("sidebar.sections.topics.links.tracked.content");
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
    if (this.totalUnread > 0) {
      return "discovery.unread";
    } else if (this.totalNew > 0) {
      return "discovery.new";
    } else {
      return "discovery.latest";
    }
  }
}
