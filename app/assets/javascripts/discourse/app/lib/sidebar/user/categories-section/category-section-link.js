import { tracked } from "@glimmer/tracking";
import { get, set } from "@ember/object";
import { bind } from "discourse/lib/decorators";
import Category from "discourse/models/category";
import { i18n } from "discourse-i18n";

const UNREAD_AND_NEW_COUNTABLE = {
  propertyName: "unreadAndNewCount",
  badgeTextFunction: (count) => count.toString(),
  route: "discovery.newCategory",
  refreshCountFunction: ({ topicTrackingState, category }) => {
    return topicTrackingState.countNewAndUnread({
      categoryId: category.id,
    });
  },
};

const DEFAULT_COUNTABLES = [
  {
    propertyName: "totalUnread",
    badgeTextFunction: (count) => {
      return i18n("sidebar.unread_count", { count });
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
      return i18n("sidebar.new_count", { count });
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

let customCategoryLockIcon;

export function registerCustomCategoryLockIcon(icon) {
  customCategoryLockIcon = icon;
}

export function resetCustomCategoryLockIcon() {
  customCategoryLockIcon = null;
}

let customCategoryPrefixes = {};

export function registerCustomCategorySectionLinkPrefix({
  categoryId,
  prefixValue,
  prefixType,
  prefixColor,
}) {
  customCategoryPrefixes[categoryId] = {
    prefixValue,
    prefixType,
    prefixColor,
  };
}

export function resetCustomCategorySectionLinkPrefix() {
  for (let key in customCategoryPrefixes) {
    if (customCategoryPrefixes.hasOwnProperty(key)) {
      delete customCategoryPrefixes[key];
    }
  }
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
    const countables = [];

    if (this.#newNewViewEnabled) {
      countables.push(UNREAD_AND_NEW_COUNTABLE);
    } else {
      countables.push(...DEFAULT_COUNTABLES);
    }

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

  get showCount() {
    return this.currentUser?.sidebarShowCountOfNewItems;
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
    return this.category.descriptionText;
  }

  get text() {
    return this.category.displayName;
  }

  get prefixType() {
    return customCategoryPrefixes[this.category.id]?.prefixType || "span";
  }

  get prefixValue() {
    const customPrefixValue =
      customCategoryPrefixes[this.category.id]?.prefixValue;

    if (customPrefixValue) {
      return customPrefixValue;
    }

    if (this.category.parentCategory?.color) {
      return [this.category.parentCategory?.color, this.category.color];
    } else {
      return [this.category.color];
    }
  }

  get prefixColor() {
    return (
      customCategoryPrefixes[this.category.id]?.prefixColor ||
      this.category.color
    );
  }

  get prefixBadge() {
    if (this.category.read_restricted) {
      return customCategoryLockIcon || "lock";
    }
  }

  get badgeText() {
    if (!this.showCount) {
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
    if (this.currentUser?.sidebarLinkToFilteredList) {
      const activeCountable = this.activeCountable;

      if (activeCountable) {
        return activeCountable.route;
      }
    }

    return "discovery.category";
  }

  get query() {
    if (this.currentUser?.sidebarLinkToFilteredList) {
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
    if (!this.showCount && this.activeCountable) {
      return "circle";
    }
  }

  get #newNewViewEnabled() {
    return !!this.currentUser?.new_new_view_enabled;
  }
}
