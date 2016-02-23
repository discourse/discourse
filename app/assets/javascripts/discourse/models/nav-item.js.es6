import { toTitleCase } from 'discourse/lib/formatter';

const NavItem = Discourse.Model.extend({

  displayName: function() {
    var categoryName = this.get('categoryName'),
        name = this.get('name'),
        count = this.get('count') || 0;

    if (name === 'latest' && !Discourse.Site.currentProp('mobileView')) {
      count = 0;
    }

    var extra = { count: count };
    var titleKey = count === 0 ? '.title' : '.title_with_count';

    if (categoryName) {
      name = 'category';
      extra.categoryName = toTitleCase(categoryName);
    }
    return I18n.t("filters." + name.replace("/", ".") + titleKey, extra);
  }.property('categoryName', 'name', 'count'),

  categoryName: function() {
    var split = this.get('name').split('/');
    return split[0] === 'category' ? split[1] : null;
  }.property('name'),

  categorySlug: function() {
    var split = this.get('name').split('/');
    if (split[0] === 'category' && split[1]) {
      var cat = Discourse.Site.current().categories.findProperty('nameLower', split[1].toLowerCase());
      return cat ? Discourse.Category.slugFor(cat) : null;
    }
    return null;
  }.property('name'),

  href: function() {
    var customHref = null;
    _.each(NavItem.customNavItemHrefs, function(cb) {
      customHref = cb.call(this, this);
      if (customHref) { return false; }
    }, this);
    if (customHref) { return customHref; }
    return Discourse.getURL("/") + this.get('filterMode');
  }.property('filterMode'),

  // href from this item
  filterMode: function() {
    var name = this.get('name');

    if( name.split('/')[0] === 'category' ) {
      return 'c/' + this.get('categorySlug');
    } else {
      var mode = "",
      category = this.get("category");

      if(category){
        mode += "c/";
        mode += Discourse.Category.slugFor(this.get('category'));
        if (this.get('noSubcategories')) { mode += '/none'; }
        mode += "/l/";
      }
      return mode + name.replace(' ', '-');
    }
  }.property('name'),

  count: function() {
    var state = this.get('topicTrackingState');
    if (state) {
      return state.lookupCount(this.get('name'), this.get('category'));
    }
  }.property('topicTrackingState.messageCount')

});

NavItem.reopenClass({

  extraArgsCallbacks: [],
  customNavItemHrefs: [],

  // create a nav item from the text, will return null if there is not valid nav item for this particular text
  fromText(text, opts) {
    var split = text.split(","),
        name = split[0],
        testName = name.split("/")[0],
        anonymous = !Discourse.User.current();

    if (anonymous && !Discourse.Site.currentProp('anonymous_top_menu_items').contains(testName)) return null;
    if (!Discourse.Category.list() && testName === "categories") return null;
    if (!Discourse.Site.currentProp('top_menu_items').contains(testName)) return null;

    var args = { name: name, hasIcon: name === "unread" }, extra = null, self = this;
    if (opts.category) { args.category = opts.category; }
    if (opts.noSubcategories) { args.noSubcategories = true; }
    _.each(NavItem.extraArgsCallbacks, function(cb) {
      extra = cb.call(self, text, opts);
      _.merge(args, extra);
    });

    const store = Discourse.__container__.lookup('store:main');
    return store.createRecord('nav-item', args);
  },

  buildList(category, args) {
    args = args || {};

    if (category) { args.category = category; }

    let items = Discourse.SiteSettings.top_menu.split("|");

    if (args.filterMode && !_.some(items, i => i.indexOf(args.filterMode) !== -1)) {
      items.push(args.filterMode);
    }

    return items.map(i => Discourse.NavItem.fromText(i, args))
                .filter(i => i !== null && !(category && i.get("name").indexOf("categor") === 0));
  }

});

export default NavItem;
export function extraNavItemProperties(cb) {
  NavItem.extraArgsCallbacks.push(cb);
}
export function customNavItemHref(cb) {
  NavItem.customNavItemHrefs.push(cb);
}
