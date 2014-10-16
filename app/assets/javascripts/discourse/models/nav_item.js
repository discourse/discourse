/**
  A data model representing a navigation item on the list views

  @class NavItem
  @extends Discourse.Model
  @namespace Discourse
  @module Discourse
**/

Discourse.NavItem = Discourse.Model.extend({

  topicTrackingState: function() {
    return Discourse.TopicTrackingState.current();
  }.property(),

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

  // href from this item
  href: function() {
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

Discourse.NavItem.reopenClass({

  // create a nav item from the text, will return null if there is not valid nav item for this particular text
  fromText: function(text, opts) {
    var split = text.split(","),
        name = split[0],
        testName = name.split("/")[0],
        anonymous = !Discourse.User.current();

    if (anonymous && !Discourse.Site.currentProp('anonymous_top_menu_items').contains(testName)) return null;
    if (!Discourse.Category.list() && testName === "categories") return null;
    if (!Discourse.Site.currentProp('top_menu_items').contains(testName)) return null;

    var args = { name: name, hasIcon: name === "unread" || name === "starred" };
    if (opts.category) { args.category = opts.category; }
    if (opts.noSubcategories) { args.noSubcategories = true; }
    return Discourse.NavItem.create(args);
  },

  buildList: function(category, args) {
    args = args || {};
    if (category) { args.category = category }

    return Discourse.SiteSettings.top_menu.split("|").map(function(i) {
      return Discourse.NavItem.fromText(i, args);
    }).filter(function(i) {
      return i !== null && !(category && i.get("name").indexOf("categor") === 0);
    });
  }

});
