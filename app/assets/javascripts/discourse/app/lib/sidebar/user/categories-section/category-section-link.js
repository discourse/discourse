import I18n from "I18n";

import { tracked } from "@glimmer/tracking";

import { bind } from "discourse-common/utils/decorators";
import Category from "discourse/models/category";
import { UNREAD_LIST_DESTINATION } from "discourse/controllers/preferences/sidebar";

export default class CategorySectionLink {
  @tracked totalUnread = 0;
  @tracked totalNew = 0;
  @tracked hideCount =
    this.currentUser?.sidebarListDestination !== UNREAD_LIST_DESTINATION;

  constructor({ category, topicTrackingState, currentUser }) {
    this.category = category;
    this.topicTrackingState = topicTrackingState;
    this.currentUser = currentUser;
    this.refreshCounts();
  }

  @bind
  refreshCounts() {
    this.totalUnread = this.topicTrackingState.countUnread({
      categoryId: this.category.id,
    });

    if (this.totalUnread === 0) {
      this.totalNew = this.topicTrackingState.countNew({
        categoryId: this.category.id,
      });
    }
  }

  get name() {
    return this.category.slug;
  }

  get model() {
    return `${Category.slugFor(this.category)}/${this.category.id}`;
  }

  get currentWhen() {
    return "discovery.unreadCategory discovery.topCategory discovery.newCategory discovery.latestCategory discovery.category discovery.categoryNone discovery.categoryAll";
  }

  get title() {
    return this.category.description_text;
  }

  get text() {
    return this.category.name;
  }

  get prefixType() {
    return "span";
  }

  get prefixElementColors() {
    return [this.category.parentCategory?.color, this.category.color];
  }

  get prefixColor() {
    return this.category.color;
  }

  get prefixBadge() {
    if (this.category.read_restricted) {
      return "lock";
    }
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
    }
  }

  get route() {
    if (this.currentUser?.sidebarListDestination === UNREAD_LIST_DESTINATION) {
      if (this.totalUnread > 0) {
        return "discovery.unreadCategory";
      }
      if (this.totalNew > 0) {
        return "discovery.newCategory";
      }
    }
    return "discovery.category";
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
