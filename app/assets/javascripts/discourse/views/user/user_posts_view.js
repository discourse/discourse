/**
  This view handles rendering of a user's posts

  @class UserPostsView
  @extends Discourse.View
  @namespace Discourse
  @uses Discourse.LoadMore
  @module Discourse
**/
Discourse.UserPostsView = Discourse.View.extend(Discourse.LoadMore, {
  loading: false,
  eyelineSelector: ".user-stream .item",
  classNames: ["user-stream"],

  actions: {
    loadMore: function() {
      var self = this;
      if (this.get("loading")) { return; }

      var postsStream = this.get("controller.model");
      postsStream.findItems().then(function () {
        self.set("loading", false);
        self.get("eyeline").flushRest();
      }).catch(function () { });
    }
  }
});
