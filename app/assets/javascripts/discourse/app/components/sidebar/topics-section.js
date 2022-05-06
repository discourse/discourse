import I18n from "I18n";

import GlimmerComponent from "discourse/components/glimmer";
import Composer from "discourse/models/composer";
import { getOwner } from "discourse-common/lib/get-owner";
import PermissionType from "discourse/models/permission-type";
import discourseDebounce from "discourse-common/lib/debounce";

import { action } from "@ember/object";
import { next } from "@ember/runloop";
import { tracked } from "@glimmer/tracking";

export default class SidebarTopicsSection extends GlimmerComponent {
  @tracked totalUnread = 0;
  @tracked totalNew = 0;

  constructor(owner, args) {
    super(owner, args);
    this._refreshSectionCounts();

    this.topicTrackingState.onStateChange(
      this._topicTrackingStateUpdated.bind(this)
    );
  }

  _topicTrackingStateUpdated() {
    // refreshing section counts by looping through the states in topicTrackingState is an expensive operation so
    // we debounce this.
    discourseDebounce(this, this._refreshSectionCounts, 100);
  }

  _refreshSectionCounts() {
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

  get everythingSectionLinkBadgeText() {
    if (this.totalUnread > 0) {
      return I18n.t("sidebar.sections.links.badge.unread_count", {
        count: this.totalUnread,
      });
    } else if (this.totalNew > 0) {
      return I18n.t("sidebar.sections.links.badge.new_count", {
        count: this.totalNew,
      });
    } else {
      return;
    }
  }

  get everythingSectionLinkRoute() {
    if (this.totalUnread > 0) {
      return "discovery.unread";
    } else if (this.totalNew > 0) {
      return "discovery.new";
    } else {
      return "discovery.latest";
    }
  }

  @action
  composeTopic() {
    const composerArgs = {
      action: Composer.CREATE_TOPIC,
      draftKey: Composer.NEW_TOPIC_KEY,
    };

    const controller = getOwner(this).lookup("controller:navigation/category");
    const category = controller.category;

    if (category && category.permission === PermissionType.FULL) {
      composerArgs.categoryId = category.id;
    }

    next(() => {
      getOwner(this).lookup("controller:composer").open(composerArgs);
    });
  }
}
