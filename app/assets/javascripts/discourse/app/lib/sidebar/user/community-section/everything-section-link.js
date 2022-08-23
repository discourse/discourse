import I18n from "I18n";

import { tracked } from "@glimmer/tracking";
import { bind } from "discourse-common/utils/decorators";
import BaseSectionLink from "discourse/lib/sidebar/user/community-section/base-section-link";

export default class EverythingSectionLink extends BaseSectionLink {
  @tracked totalUnread = 0;
  @tracked totalNew = 0;
  callbackId = null;

  constructor() {
    super(...arguments);

    this.callbackId = this.topicTrackingState.onStateChange(
      this._refreshCounts
    );

    this._refreshCounts();
  }

  teardown() {
    this.topicTrackingState.offStateChange(this.callbackId);
  }

  @bind
  _refreshCounts() {
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
    if (this.totalUnread > 0) {
      return "discovery.unread";
    } else if (this.totalNew > 0) {
      return "discovery.new";
    } else {
      return "discovery.latest";
    }
  }
}
