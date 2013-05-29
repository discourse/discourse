/**
  A data model representing a navigation item on the list views

  @class InviteList
  @extends Discourse.Model
  @namespace Discourse
  @module Discourse
**/
var validNavNames = ['latest', 'hot', 'categories', 'category', 'favorited', 'unread', 'new', 'read', 'posted'];
var validAnon     = ['latest', 'hot', 'categories', 'category'];

Discourse.NavItem = Discourse.Model.extend({
  topicTrackingState: function(){
    return Discourse.TopicTrackingState.current();
  }.property(),

  categoryName: function() {
    var split = this.get('name').split('/');
    return split[0] === 'category' ? split[1] : null;
  }.property('name'),

  // href from this item
  href: function() {
    var name = this.get('name'),
        href = Discourse.getURL("/") + name.replace(' ', '-');
    if (name === 'category') href += "/" + this.get('categoryName');
    return href;
  }.property('name'),

  count: function() {
    var state = this.get('topicTrackingState');
    if (state) {
      return state.lookupCount(this.get('name'));
    }
  }.property('topicTrackingState.messageCount')
});

Discourse.NavItem.reopenClass({

  // create a nav item from the text, will return null if there is not valid nav item for this particular text
  fromText: function(text, opts) {
    var countSummary = opts.countSummary,
        split = text.split(","),
        name = split[0],
        testName = name.split("/")[0];

    if (!opts.loggedOn && !validAnon.contains(testName)) return null;
    if (!Discourse.Category.list() && testName === "categories") return null;
    if (!validNavNames.contains(testName)) return null;

    opts = {
      name: name,
      hasIcon: name === "unread" || name === "favorited",
      filters: split.splice(1)
    };

    // if (countSummary && countSummary[name]) opts.count = countSummary[name];

    return Discourse.NavItem.create(opts);
  }

});
