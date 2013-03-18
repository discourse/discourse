/**
  A data model representing a navigation item on the list views

  @class InviteList
  @extends Discourse.Model
  @namespace Discourse
  @module Discourse
**/
var validAnon, validNavNames;
validNavNames = ['read', 'popular', 'categories', 'favorited', 'category', 'unread', 'new', 'posted'];
validAnon = ['popular', 'category', 'categories'];

Discourse.NavItem = Discourse.Model.extend({
  categoryName: (function() {
    var split;
    split = this.get('name').split('/');
    if (split[0] === 'category') {
      return split[1];
    } else {
      return null;
    }
  }).property(),
  href: (function() {
    /* href from this item
    */

    var name;
    name = this.get('name');
    if (name === 'category') {
      return Discourse.getURL("/") + name + "/" + (this.get('categoryName'));
    } else {
      return Discourse.getURL("/") + name;
    }
  }).property()
});

Discourse.NavItem.reopenClass({

  // create a nav item from the text, will return null if there is not valid nav item for this particular text
  fromText: function(text, opts) {
    var countSummary, hasCategories, loggedOn, name, split, testName;
    countSummary = opts.countSummary;
    loggedOn = opts.loggedOn;
    hasCategories = opts.hasCategories;
    split = text.split(",");
    name = split[0];
    testName = name.split("/")[0];

    if (!loggedOn && !validAnon.contains(testName)) return null;
    if (!hasCategories && testName === "categories") return null;
    if (!validNavNames.contains(testName)) return null;

    opts = {
      name: name,
      hasIcon: name === "unread" || name === "favorited",
      filters: split.splice(1)
    };
    if (countSummary) {
      if (countSummary && countSummary[name]) {
        opts.count = countSummary[name];
      }
    }
    return Discourse.NavItem.create(opts);
  }

});


