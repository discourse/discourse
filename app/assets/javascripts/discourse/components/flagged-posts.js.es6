export default Ember.Component.extend({
  canAct: Ember.computed.equal("filter", "active"),
  showResolvedBy: Ember.computed.equal("filter", "old"),
  allLoaded: false,

  actions: {
    removePost(flaggedPost) {
      this.get("flaggedPosts").removeObject(flaggedPost);
    },

    loadMore() {
      const flaggedPosts = this.get("flaggedPosts");
      if (flaggedPosts.get("canLoadMore")) {
        flaggedPosts.loadMore();
      }
    }
  }
});
