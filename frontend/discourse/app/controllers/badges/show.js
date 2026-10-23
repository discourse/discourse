import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import EmberObject, { action } from "@ember/object";
import { uniqueItemsFromArray } from "discourse/lib/array-tools";
import { autoTrackedArray } from "discourse/lib/tracked-tools";
import Badge from "discourse/models/badge";
import UserBadge from "discourse/models/user-badge";
import { i18n } from "discourse-i18n";

export default class ShowController extends Controller {
  @tracked model;

  /** @type {string | null} */
  @tracked username = null;
  @tracked loadingMore = false;
  @tracked noMoreBadges = false;
  @tracked showTitlePicker = false;
  @tracked userBadgesAll;
  @tracked userBadgesGrantCount;

  /** @type {import("discourse/models/user-badge").default[] | null} */
  @autoTrackedArray userBadges = null;

  queryParams = ["username"];

  get selectableUserBadges() {
    return [
      EmberObject.create({
        id: 0,
        badge: Badge.create({ name: i18n("badges.none") }),
      }),
      ...uniqueItemsFromArray(
        this.userBadgesAll.filter((ub) => ub.badge.allow_title),
        "badge.name"
      ),
    ];
  }

  get othersCount() {
    return this.model.grant_count - this.userBadgesGrantCount;
  }

  get currentUserHasBadge() {
    return !!this.userBadgesAll?.some((ub) => ub.badge?.id === this.model.id);
  }

  get isFilteredToOtherUser() {
    return (
      !!this.username && this.userBadges?.[0]?.user?.id !== this.currentUser?.id
    );
  }

  get hasBadge() {
    return this.username
      ? this.userBadgesGrantCount > 0
      : this.currentUserHasBadge;
  }

  get canSelectTitle() {
    return (
      this.siteSettings.enable_badges &&
      this.model.allow_title &&
      this.hasBadge &&
      !this.isFilteredToOtherUser
    );
  }

  get canLoadMore() {
    if (this.noMoreBadges) {
      return false;
    }
    const total = this.userBadgesGrantCount ?? this.model.grant_count;
    return total > (this.userBadges?.length || 0);
  }

  get canShowOthers() {
    return !!this.username && this.othersCount > 0;
  }

  @action
  async loadMore() {
    if (!this.canLoadMore || this.loadingMore) {
      return;
    }

    this.loadingMore = true;

    try {
      const userBadges = this.userBadges;
      const result = await UserBadge.findByBadgeId(this.model.id, {
        offset: userBadges.length,
        username: this.username,
      });

      userBadges.push(...result);
      if (userBadges.length === 0) {
        this.noMoreBadges = true;
      }
    } finally {
      this.loadingMore = false;
    }
  }

  @action
  toggleTitlePicker() {
    this.showTitlePicker = !this.showTitlePicker;
  }
}
