import I18n from "I18n";

import { tracked } from "@glimmer/tracking";

import discourseDebounce from "discourse-common/lib/debounce";
import BaseSectionLink from "discourse/lib/sidebar/topics-section/base-section-link";

export default class EverythingSectionLink extends BaseSectionLink {
  @tracked totalUnread = 0;
  @tracked totalNew = 0;

  constructor() {
    super(...arguments);

    this._refreshCounts();

    this.topicTrackingState.onStateChange(
      this._topicTrackingStateUpdated.bind(this)
    );
  }

  _topicTrackingStateUpdated() {
    // refreshing section counts by looping through the states in topicTrackingState is an expensive operation so
    // we debounce this.
    discourseDebounce(this, this._refreshCounts, 100);
  }

  _refreshCounts() {
    let totalUnread = 0;
    let totalNew = 0;

    this.topicTrackingState.forEachTracked((topic, isNew, isUnread) => {
      if (isNew) {
        totalNew += 1;
      } else if (isUnread) {
        totalUnread += 1;
      }
    });

    this.totalUnread = totalUnread;
    this.totalNew = totalNew;
  }

  get name() {
    return "everything";
  }

  get query() {
    return { f: undefined };
  }

  get title() {
    return I18n.t("sidebar.sections.topics.links.everything.title");
  }

  get text() {
    return I18n.t("sidebar.sections.topics.links.everything.content");
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
    if (this.totalUnread > 0) {
      return "discovery.unread";
    } else if (this.totalNew > 0) {
      return "discovery.new";
    } else {
      return "discovery.latest";
    }
  }
}
