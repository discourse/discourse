import discourseComputed from "discourse-common/utils/decorators";
import { emojiUnescape } from "discourse/lib/text";
import Category from "discourse/models/category";
import EmberObject from "@ember/object";
import deprecated from "discourse-common/lib/deprecated";
import Site from "discourse/models/site";

const NavItem = EmberObject.extend({
  @discourseComputed("name")
  title(name) {
    const extra = {};

    return I18n.t("filters." + name.replace("/", ".") + ".help", extra);
  },

  @discourseComputed("name", "count")
  displayName(name, count) {
    count = count || 0;

    if (
      name === "latest" &&
      (!Site.currentProp("mobileView") || this.tagId !== undefined)
    ) {
      count = 0;
    }

    let extra = { count: count };
    const titleKey = count === 0 ? ".title" : ".title_with_count";

    return emojiUnescape(
      I18n.t(`filters.${name.replace("/", ".") + titleKey}`, extra)
    );
  },

  @discourseComputed("filterMode")
  href(filterMode) {
    let customHref = null;

    NavItem.customNavItemHrefs.forEach(function(cb) {
      customHref = cb.call(this, this);
      if (customHref) {
        return false;
      }
    }, this);

    if (customHref) {
      return customHref;
    }

    return Discourse.getURL("/") + filterMode;
  },

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
  },

  @discourseComputed("name", "category", "topicTrackingState.messageCount")
  count(name, category) {
    const state = this.topicTrackingState;
    if (state) {
      return state.lookupCount(name, category);
    }
  }
});

const ExtraNavItem = NavItem.extend({
  href: discourseComputed("href", {
    get() {
      if (this._href) {
        return this._href;
      }

      return this.href;
    },

    set(key, value) {
      return (this._href = value);
    }
  }),

  count: 0,

  customFilter: null
});

NavItem.reopenClass({
  extraArgsCallbacks: [],
  customNavItemHrefs: [],
  extraNavItemDescriptors: [],

  // create a nav item from the text, will return null if there is not valid nav item for this particular text
  fromText(text, opts) {
    var testName = text.split("/")[0],
      anonymous = !Discourse.User.current();

    opts = opts || {};

    if (
      anonymous &&
      !Site.currentProp("anonymous_top_menu_items").includes(testName)
    )
      return null;

    if (!Category.list() && testName === "categories") return null;
    if (!Site.currentProp("top_menu_items").includes(testName)) return null;

    var args = { name: text, hasIcon: text === "unread" };
    if (opts.category) {
      args.category = opts.category;
    }
    if (opts.tagId) {
      args.tagId = opts.tagId;
    }
    if (opts.persistedQueryParams) {
      args.persistedQueryParams = opts.persistedQueryParams;
    }
    if (opts.noSubcategories) {
      args.noSubcategories = true;
    }
    NavItem.extraArgsCallbacks.forEach(cb =>
      _.merge(args, cb.call(this, text, opts))
    );

    const store = Discourse.__container__.lookup("service:store");
    return store.createRecord("nav-item", args);
  },

  buildList(category, args) {
    args = args || {};

    if (category) {
      args.category = category;
    }

    let items = Discourse.SiteSettings.top_menu.split("|");

    if (
      args.filterMode &&
      !items.some(i => i.indexOf(args.filterMode) !== -1)
    ) {
      items.push(args.filterMode);
    }

    items = items
      .map(i => NavItem.fromText(i, args))
      .filter(
        i => i !== null && !(category && i.get("name").indexOf("categor") === 0)
      );

    const extraItems = NavItem.extraNavItemDescriptors
      .map(descriptor => ExtraNavItem.create(descriptor))
      .filter(item => {
        if (!item.customFilter) return true;
        return item.customFilter(category, args);
      });

    let forceActive = false;

    extraItems.forEach(item => {
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
        item.set("href", item.customHref(category, args));
      }

      if (item.forceActive && item.forceActive(category, args)) {
        item.active = true;
        forceActive = true;
      } else {
        item.active = undefined;
      }
    });

    if (forceActive) {
      items.forEach(i => {
        if (i.active === undefined) {
          i.active = false;
        }
      });
    }
    return items;
  }
});

export default NavItem;

export function extraNavItemProperties(cb) {
  NavItem.extraArgsCallbacks.push(cb);
}

export function customNavItemHref(cb) {
  NavItem.customNavItemHrefs.push(cb);
}

export function addNavItem(item) {
  NavItem.extraNavItemDescriptors.push(item);
}

Object.defineProperty(Discourse, "NavItem", {
  get() {
    deprecated("Import the NavItem class instead of using Discourse.NavItem", {
      since: "2.4.0",
      dropFrom: "2.5.0"
    });
    return NavItem;
  }
});
