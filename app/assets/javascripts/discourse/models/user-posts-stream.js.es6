import { ajax } from "discourse/lib/ajax";
import { url } from "discourse/lib/computed";
import UserAction from "discourse/models/user-action";

export default Discourse.Model.extend({
  loaded: false,

  _initialize: function() {
    this.setProperties({
      itemsLoaded: 0,
      canLoadMore: true,
      content: []
    });
  }.on("init"),

  url: url(
    "user.username_lower",
    "filter",
    "itemsLoaded",
    "/posts/%@/%@?offset=%@"
  ),

  filterBy(opts) {
    if (this.get("loaded") && this.get("filter") === opts.filter) {
      return Ember.RSVP.resolve();
    }

    this.setProperties(
      Object.assign(
        {
          itemsLoaded: 0,
          content: [],
          lastLoadedUrl: null
        },
        opts
      )
    );

    return this.findItems();
  },

  findItems() {
    const self = this;
    if (this.get("loading") || !this.get("canLoadMore")) {
      return Ember.RSVP.reject();
    }

    this.set("loading", true);

    return ajax(this.get("url"), { cache: false })
      .then(function(result) {
        if (result) {
          const posts = result.map(function(post) {
            return UserAction.create(post);
          });
          self.get("content").pushObjects(posts);
          self.setProperties({
            loaded: true,
            itemsLoaded: self.get("itemsLoaded") + posts.length,
            canLoadMore: posts.length > 0
          });
        }
      })
      .finally(function() {
        self.set("loading", false);
      });
  }
});
