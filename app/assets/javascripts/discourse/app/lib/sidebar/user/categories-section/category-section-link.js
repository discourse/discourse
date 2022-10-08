import I18n from "I18n";

import { tracked } from "@glimmer/tracking";

import { bind } from "discourse-common/utils/decorators";
import Category from "discourse/models/category";

export default class CategorySectionLink {
  @tracked totalUnread = 0;
  @tracked totalNew = 0;

  constructor({ category, topicTrackingState }) {
    this.category = category;
    this.topicTrackingState = topicTrackingState;
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
    return "discovery.unreadCategory discovery.topCategory discovery.newCategory discovery.latestCategory discovery.category";
  }

  get title() {
    return this.category.description_text;
  }

  get text() {
    return this.category.name;
  }

  get prefixType() {
    return "icon";
  }

  get prefixValue() {
    return "square-full";
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
    return "discovery.category";
  }
}
