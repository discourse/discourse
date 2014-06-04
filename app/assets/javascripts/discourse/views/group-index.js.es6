/**
  Displays all posts within a group

  @class Discourse.GroupIndexView
  @extends Ember.Mixin
  @namespace Discourse
  @module Discourse
**/
export default Discourse.View.extend(Discourse.ScrollTop, Discourse.LoadMore, {
  eyelineSelector: '.user-stream .item',
});
