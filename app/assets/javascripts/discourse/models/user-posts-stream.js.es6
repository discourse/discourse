import { url } from 'discourse/lib/computed';
import AdminPost from 'discourse/models/admin-post';

export default Discourse.Model.extend({
  loaded: false,

  _initialize: function () {
    this.setProperties({
      itemsLoaded: 0,
      canLoadMore: true,
      content: []
    });
  }.on("init"),

  url: url("user.username_lower", "filter", "itemsLoaded", "/posts/%@/%@?offset=%@"),

  filterBy(filter) {
    if (this.get("loaded") && this.get("filter") === filter) { return Ember.RSVP.resolve(); }

    this.setProperties({
      filter: filter,
      itemsLoaded: 0,
      canLoadMore: true,
      content: []
    });

    return this.findItems();
  },

  findItems() {
    const self = this;
    if (this.get("loading") || !this.get("canLoadMore")) { return Ember.RSVP.reject(); }

    this.set("loading", true);

    return Discourse.ajax(this.get("url"), { cache: false }).then(function (result) {
      if (result) {
        const posts = result.map(function (post) { return AdminPost.create(post); });
        self.get("content").pushObjects(posts);
        self.setProperties({
          loaded: true,
          itemsLoaded: self.get("itemsLoaded") + posts.length,
          canLoadMore: posts.length > 0
        });
      }
    }).finally(function () {
      self.set("loading", false);
    });
  }

});
