/**
  Handles the controller for the default navigation within discovery.

  @class NavigationDefaultController
  @extends Discourse.Controller
  @namespace Discourse
  @module Discourse
**/
export default Discourse.Controller.extend({
  categories: function() {
    return Discourse.Category.list();
  }.property(),

  navItems: function() {
    return Discourse.NavItem.buildList();
  }.property()
});
