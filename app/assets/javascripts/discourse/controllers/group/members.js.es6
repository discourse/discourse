export default Ember.ObjectController.extend({
  loading: false,

  actions: {
    loadMore() {
      if (this.get("loading")) { return; }
      // we've reached the end
      if (this.get("members.length") >= this.get("user_count")) { return; }

      this.set("loading", true);

      const self = this;

      Discourse.Group.loadMembers(this.get("name"), this.get("members.length"), this.get("limit")).then(function (result) {
        self.get("members").addObjects(result.members.map(member => Discourse.User.create(member)));
        self.setProperties({
          loading: false,
          user_count: result.meta.total,
          limit: result.meta.limit,
          offset: Math.min(result.meta.offset + result.meta.limit, result.meta.total)
        });
      });
    }
  }
});

