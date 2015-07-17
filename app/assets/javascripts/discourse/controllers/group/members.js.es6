export default Ember.ObjectController.extend({
  loading: false,

  actions: {
    loadMore() {
      if (this.get("loading")) { return; }
      // we've reached the end
      if (this.get("model.members.length") >= this.get("user_count")) { return; }

      this.set("loading", true);

      Discourse.Group.loadMembers(this.get("name"), this.get("model.members.length"), this.get("limit")).then(result => {
        this.get("model.members").addObjects(result.members.map(member => Discourse.User.create(member)));
        this.setProperties({
          loading: false,
          user_count: result.meta.total,
          limit: result.meta.limit,
          offset: Math.min(result.meta.offset + result.meta.limit, result.meta.total)
        });
      });
    }
  }
});
