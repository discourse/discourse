import { toTitleCase } from "discourse/lib/formatter";
import { emojiUnescape } from "discourse/lib/text";
import computed from "ember-addons/ember-computed-decorators";

const NavItem = Discourse.Model.extend({
  @computed("categoryName", "name")
  title(categoryName, name) {
    const extra = {};

    if (categoryName) {
      name = "category";
      extra.categoryName = categoryName;
    }

    return I18n.t("filters." + name.replace("/", ".") + ".help", extra);
  },

  @computed("categoryName", "name", "count")
  displayName(categoryName, name, count) {
    count = count || 0;

    if (name === "latest" && !Discourse.Site.currentProp("mobileView")) {
      count = 0;
    }

    let extra = { count: count };
    const titleKey = count === 0 ? ".title" : ".title_with_count";

    if (categoryName) {
      name = "category";
      extra.categoryName = toTitleCase(categoryName);
    }

    return emojiUnescape(
      I18n.t(`filters.${name.replace("/", ".") + titleKey}`, extra)
    );
  },

  @computed("name")
  categoryName(name) {
    const split = name.split("/");
    return split[0] === "category" ? split[1] : null;
  },

  @computed("name")
  categorySlug(name) {
    const split = name.split("/");
    if (split[0] === "category" && split[1]) {
      const cat = Discourse.Site.current().categories.findBy(
        "nameLower",
        split[1].toLowerCase()
      );
      return cat ? Discourse.Category.slugFor(cat) : null;
    }
    return null;
  },

  @computed("filterMode")
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

  @computed("name", "category", "categorySlug", "noSubcategories")
  filterMode(name, category, categorySlug, noSubcategories) {
    if (name.split("/")[0] === "category") {
      return "c/" + categorySlug;
    } else {
      let mode = "";
      if (category) {
        mode += "c/";
        mode += Discourse.Category.slugFor(category);
        if (noSubcategories) {
          mode += "/none";
        }
        mode += "/l/";
      }
      return mode + name.replace(" ", "-");
    }
  },

  @computed("name", "category", "topicTrackingState.messageCount")
  count(name, category) {
    const state = this.get("topicTrackingState");
    if (state) {
      return state.lookupCount(name, category);
    }
  }
});

const ExtraNavItem = NavItem.extend({
  @computed("href")
  href: href => href,
  customFilter: null
});

NavItem.reopenClass({
  extraArgsCallbacks: [],
  customNavItemHrefs: [],
  extraNavItems: [],

  // create a nav item from the text, will return null if there is not valid nav item for this particular text
  fromText(text, opts) {
    var split = text.split(","),
      name = split[0],
      testName = name.split("/")[0],
      anonymous = !Discourse.User.current();

    opts = opts || {};

    if (
      anonymous &&
      !Discourse.Site.currentProp("anonymous_top_menu_items").includes(testName)
    )
      return null;

    if (!Discourse.Category.list() && testName === "categories") return null;
    if (!Discourse.Site.currentProp("top_menu_items").includes(testName))
      return null;

    var args = { name: name, hasIcon: name === "unread" },
      extra = null,
      self = this;
    if (opts.category) {
      args.category = opts.category;
    }
    if (opts.noSubcategories) {
      args.noSubcategories = true;
    }
    NavItem.extraArgsCallbacks.forEach(cb => {
      extra = cb.call(self, text, opts);
      _.merge(args, extra);
    });

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
      .map(i => Discourse.NavItem.fromText(i, args))
      .filter(
        i => i !== null && !(category && i.get("name").indexOf("categor") === 0)
      );

    const extraItems = NavItem.extraNavItems.filter(item => {
      if (!item.customFilter) return true;
      return item.customFilter.call(this, category, args);
    });

    return items.concat(extraItems);
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
  NavItem.extraNavItems.push(ExtraNavItem.create(item));
}
