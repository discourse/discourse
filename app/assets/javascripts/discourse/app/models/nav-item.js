import { tracked } from "@glimmer/tracking";
import EmberObject from "@ember/object";
import { dependentKeyCompat } from "@ember/object/compat";
import { reads } from "@ember/object/computed";
import { service } from "@ember/service";
import discourseComputed from "discourse/lib/decorators";
import deprecated from "discourse/lib/deprecated";
import { getOwnerWithFallback } from "discourse/lib/get-owner";
import getURL from "discourse/lib/get-url";
import { deepMerge } from "discourse/lib/object";
import { emojiUnescape } from "discourse/lib/text";
import {
  hasTrackedFilter,
  isTrackedTopic,
} from "discourse/lib/topic-list-tracked-filter";
import Category from "discourse/models/category";
import Site from "discourse/models/site";
import User from "discourse/models/user";
import { i18n } from "discourse-i18n";

export default class NavItem extends EmberObject {
  static extraArgsCallbacks = [];
  static customNavItemHrefs = [];
  static extraNavItemDescriptors = [];

  static pathFor(filterType, context) {
    let path = getURL("");
    let includesCategoryContext = false;
    let includesTagContext = false;

    if (filterType === "categories") {
      path += "/categories";
      return path;
    }

    if (context.tagId && Site.currentProp("filters").includes(filterType)) {
      includesTagContext = true;

      if (context.category) {
        path += "/tags";
      } else {
        path += "/tag";
      }
    }

    if (context.category) {
      includesCategoryContext = true;
      path += `/c/${Category.slugFor(context.category)}/${context.category.id}`;

      if (context.noSubcategories) {
        path += "/none";
      }
    }

    if (includesTagContext) {
      path += `/${context.tagId}`;
    }

    if (includesTagContext || includesCategoryContext) {
      path += "/l";
    }

    path += `/${filterType}`;

    // In the case of top, the nav item doesn't include a period because the
    // period has its own selector just below

    return path;
  }

  // Create a nav item given a filterType. It returns null if there is not
  // valid nav item. The name is a historical artifact.
  static fromText(filterType, opts) {
    const anonymous = !User.current();

    opts = opts || {};

    if (anonymous) {
      const topMenuItems = Site.currentProp("anonymous_top_menu_items");
      if (!topMenuItems || !topMenuItems.includes(filterType)) {
        return null;
      }
    }

    if (!Category.list() && filterType === "categories") {
      return null;
    }
    if (!Site.currentProp("top_menu_items").includes(filterType)) {
      return null;
    }

    let args = { name: filterType, hasIcon: filterType === "unread" };
    if (opts.category) {
      args.category = opts.category;
    }
    if (opts.tagId) {
      args.tagId = opts.tagId;
    }
    if (opts.currentRouteQueryParams) {
      args.currentRouteQueryParams = opts.currentRouteQueryParams;
    }
    if (opts.noSubcategories) {
      args.noSubcategories = true;
    }
    NavItem.extraArgsCallbacks.forEach((cb) =>
      deepMerge(args, cb.call(this, filterType, opts))
    );

    let store = getOwnerWithFallback(this).lookup("service:store");
    return store.createRecord("nav-item", args);
  }

  static buildList(category, args) {
    args = args || {};

    if (category) {
      args.category = category;
    }

    if (!args.siteSettings) {
      deprecated("You must supply `buildList` with a `siteSettings` object", {
        since: "2.6.0",
        dropFrom: "2.7.0",
        id: "discourse.nav-item.built-list-site-settings",
      });
      args.siteSettings = getOwnerWithFallback(this).lookup(
        "service:site-settings"
      );
    }
    let items = args.siteSettings.top_menu.split("|");

    const user = getOwnerWithFallback(this).lookup("service:current-user");
    if (user?.new_new_view_enabled) {
      items = items.reject((item) => item === "unread");
    }
    const filterType = (args.filterMode || "").split("/").pop();

    if (!items.some((i) => filterType === i)) {
      items.push(filterType);
    }

    items = items
      .map((i) => NavItem.fromText(i, args))
      .filter((i) => {
        if (i === null) {
          return false;
        }

        if (
          (category || args.skipCategoriesNavItem) &&
          i.name.startsWith("categor")
        ) {
          return false;
        }

        return true;
      });

    const context = {
      category: args.category,
      tagId: args.tagId,
      noSubcategories: args.noSubcategories,
    };

    const extraItems = NavItem.extraNavItemDescriptors
      .map((descriptor) =>
        ExtraNavItem.create(deepMerge({}, context, descriptor))
      )
      .filter((item) => {
        if (!item.customFilter) {
          return true;
        }
        return item.customFilter(category, args);
      });

    let forceActive = false;

    extraItems.forEach((item) => {
      if (item.init) {
        item.init(item, category, args);
      }

      const before = item.before;
      if (before) {
        let i = 0;
        for (i = 0; i < items.length; i++) {
          if (items[i].name === before) {
            break;
          }
        }
        items.splice(i, 0, item);
      } else {
        items.push(item);
      }

      if (item.customHref) {
        item.href = item.customHref(category, args);
      } else if (item.href) {
        item.href = getURL(item.href);
      }

      if (item.forceActive && item.forceActive(category, args)) {
        item.active = true;
        forceActive = true;
      } else {
        item.active = undefined;
      }
    });

    if (forceActive) {
      items.forEach((i) => {
        if (i.active === undefined) {
          i.active = false;
        }
      });
    }
    return items;
  }

  @service topicTrackingState;

  @tracked name;
  @reads("name") filterType;

  @tracked _title;
  @tracked _displayName;

  @dependentKeyCompat
  get title() {
    if (this._title) {
      return this._title;
    }

    return i18n("filters." + this.name.replace("/", ".") + ".help", {});
  }

  set title(value) {
    this._title = value;
  }

  @dependentKeyCompat
  get displayName() {
    if (this._displayName) {
      return this._displayName;
    }

    let count = this.count || 0;

    if (
      this.name === "latest" &&
      (Site.currentProp("desktopView") || this.tagId !== undefined)
    ) {
      count = 0;
    }

    let extra = { count };
    const titleKey = count === 0 ? ".title" : ".title_with_count";

    return emojiUnescape(
      i18n(`filters.${this.name.replace("/", ".") + titleKey}`, extra)
    );
  }

  set displayName(value) {
    this._displayName = value;
  }

  @discourseComputed("filterType", "category", "noSubcategories", "tagId")
  href(filterType, category, noSubcategories, tagId) {
    let customHref = null;

    NavItem.customNavItemHrefs.forEach(function (cb) {
      customHref = cb.call(this, this);
      if (customHref) {
        return false;
      }
    }, this);

    if (customHref) {
      return getURL(customHref);
    }

    const context = { category, noSubcategories, tagId };
    return NavItem.pathFor(filterType, context);
  }

  @discourseComputed("name", "category", "noSubcategories")
  filterMode(name, category, noSubcategories) {
    let mode = "";
    if (category) {
      mode += "c/";
      mode += Category.slugFor(category);
      if (noSubcategories) {
        mode += "/none";
      }
      mode += "/l/";
    }
    return mode + name.replace(" ", "-");
  }

  @discourseComputed(
    "name",
    "category",
    "tagId",
    "noSubcategories",
    "currentRouteQueryParams",
    "topicTrackingState.messageCount"
  )
  count(name, category, tagId, noSubcategories, currentRouteQueryParams) {
    return this.topicTrackingState?.lookupCount({
      type: name,
      category,
      tagId,
      noSubcategories,
      customFilterFn: hasTrackedFilter(currentRouteQueryParams)
        ? isTrackedTopic
        : undefined,
    });
  }
}

export class ExtraNavItem extends NavItem {
  @tracked href;
  @tracked count = 0;
  customFilter = null;
}

export function extraNavItemProperties(cb) {
  NavItem.extraArgsCallbacks.push(cb);
}

export function customNavItemHref(cb) {
  NavItem.customNavItemHrefs.push(cb);
}

export function clearNavItems() {
  NavItem.customNavItemHrefs.clear();
  NavItem.extraArgsCallbacks.clear();
  NavItem.extraNavItemDescriptors.clear();
}

export function addNavItem(item) {
  NavItem.extraNavItemDescriptors.push(item);
}
