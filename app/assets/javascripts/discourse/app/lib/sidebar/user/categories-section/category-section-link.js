import I18n from "I18n";

import { tracked } from "@glimmer/tracking";
import { get, set } from "@ember/object";

import { bind } from "discourse-common/utils/decorators";
import Category from "discourse/models/category";
import { UNREAD_LIST_DESTINATION } from "discourse/controllers/preferences/sidebar";

const DEFAULT_COUNTABLES = [
  {
    propertyName: "totalUnread",
    badgeTextFunction: (count) => {
      return I18n.t("sidebar.unread_count", { count });
    },
    route: "discovery.unreadCategory",
    refreshCountFunction: ({ topicTrackingState, category }) => {
      return topicTrackingState.countUnread({
        categoryId: category.id,
      });
    },
  },
  {
    propertyName: "totalNew",
    badgeTextFunction: (count) => {
      return I18n.t("sidebar.new_count", { count });
    },
    route: "discovery.newCategory",
    refreshCountFunction: ({ topicTrackingState, category }) => {
      return topicTrackingState.countNew({
        categoryId: category.id,
      });
    },
  },
];

const customCountables = [];

export function registerCustomCountable({
  badgeTextFunction,
  route,
  routeQuery,
  shouldRegister,
  refreshCountFunction,
  prioritizeOverDefaults,
}) {
  const length = customCountables.length + 1;

  customCountables.push({
    propertyName: `customCountableProperty${length}`,
    badgeTextFunction,
    route,
    routeQuery,
    shouldRegister,
    refreshCountFunction,
    prioritizeOverDefaults,
  });
}

export function resetCustomCountables() {
  customCountables.length = 0;
}

export default class CategorySectionLink {
  @tracked activeCountable;

  constructor({ category, topicTrackingState, currentUser }) {
    this.category = category;
    this.topicTrackingState = topicTrackingState;
    this.currentUser = currentUser;
    this.countables = this.#countables();

    this.refreshCounts();
  }

  #countables() {
    const countables = [...DEFAULT_COUNTABLES];

    if (customCountables.length > 0) {
      customCountables.forEach((customCountable) => {
        if (
          !customCountable.shouldRegister ||
          customCountable.shouldRegister({ category: this.category })
        ) {
          if (
            customCountable?.prioritizeOverDefaults({
              category: this.category,
              currentUser: this.currentUser,
            })
          ) {
            countables.unshift(customCountable);
          } else {
            countables.push(customCountable);
          }
        }
      });
    }

    return countables;
  }

  get hideCount() {
    return this.currentUser?.sidebarListDestination !== UNREAD_LIST_DESTINATION;
  }

  @bind
  refreshCounts() {
    this.countables = this.#countables();

    this.activeCountable = this.countables.find((countable) => {
      const count = countable.refreshCountFunction({
        topicTrackingState: this.topicTrackingState,
        category: this.category,
      });

      set(this, countable.propertyName, count);
      return count > 0;
    });
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
    return this.category.description;
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

    const activeCountable = this.activeCountable;

    if (activeCountable) {
      return activeCountable.badgeTextFunction(
        get(this, activeCountable.propertyName)
      );
    }
  }

  get route() {
    if (this.currentUser?.sidebarListDestination === UNREAD_LIST_DESTINATION) {
      const activeCountable = this.activeCountable;

      if (activeCountable) {
        return activeCountable.route;
      }
    }

    return "discovery.category";
  }

  get query() {
    if (this.currentUser?.sidebarListDestination === UNREAD_LIST_DESTINATION) {
      const activeCountable = this.activeCountable;

      if (activeCountable?.routeQuery) {
        return activeCountable.routeQuery;
      }
    }
  }

  get suffixCSSClass() {
    return "unread";
  }

  get suffixType() {
    return "icon";
  }

  get suffixValue() {
    if (this.hideCount && this.activeCountable) {
      return "circle";
    }
  }
}
